/**
 * @description Implementation of the Home dashboard use case (HFS-32). Resolves the running
 * partner's Account, reads the account summary, and computes the four summary tiles (Active
 * Orders, Downloads This Month, Training Progress, Open Requests) plus the optional announcement
 * banner. Read-only - no DML, no commitWork(). Each source is wrapped in its OWN try/catch and
 * degrades to an UNAVAILABLE tile status on failure, so one failing source never zeros or blocks
 * the others (AC2/AC4, Edge cases). No SOQL in loops - each count is one query then in-memory work.
 */
public inherited sharing class hfs_HomeDashboardServiceImpl implements hfs_HomeDashboardService {
  private static final String STATUS_COMPLETED = 'Completed';
  private static final String ORDER_ACTIVATED = 'Activated';

  private static final String TILE_ACTIVE_ORDERS = 'activeOrders';
  private static final String TILE_DOWNLOADS = 'downloads';
  private static final String TILE_TRAINING = 'training';
  private static final String TILE_OPEN_REQUESTS = 'openRequests';

  private static final String ACCENT_BLUE = '#1B6ACB';
  private static final String ACCENT_GREEN = '#157347';
  private static final String ACCENT_AMBER = '#C98A12';
  private static final String ACCENT_RED = '#C8102E';

  /**
   * @description Test-only seam. When set to true, every per-source read throws so the resilience
   * catch/UNAVAILABLE branches can be covered deterministically (a WITH USER_MODE query is not a
   * reliable way to force a throw for an internal test user).
   */
  @TestVisible
  private static Boolean forceFailure = false;

  /**
   * @description Builds the personalised Home dashboard payload for the given user.
   * @param userId the signed-in user whose dashboard should be assembled
   * @return the populated dashboard DTO
   */
  public hfs_HomeDashboardDTO buildDashboard(Id userId) {
    hfs_HomeDashboardDTO dto = new hfs_HomeDashboardDTO();

    // 1. Resolve the real partner context (User -> Contact -> Account). This is the production
    //    path: once Customer Community self-registration exists, external users resolve here and
    //    the internal-preview fallback below is never reached (no future code change needed).
    User partner = resolvePartner(userId);
    if (partner != null && partner.Contact != null && partner.Contact.AccountId != null) {
      return buildForAccount(partner.Contact.AccountId, buildAccountSummary(partner), userId);
    }

    // 2. Fallback for INTERNAL users only (e.g. admins/testers with no partner Account). Governed
    //    by the hfs_Home_Dashboard_Preview__mdt config; disabled by default. This lets QA exercise
    //    the story before external users can self-register. Access is never widened for a real
    //    partner - a resolved partner always returns above and never touches this branch.
    Account previewAcct = resolvePreviewAccount();
    if (previewAcct != null) {
      hfs_HomeDashboardDTO.AccountSummary summary = buildAccountSummary(
        UserInfo.getFirstName(),
        previewAcct
      );
      return buildForAccount(previewAcct.Id, summary, userId);
    }

    // 3. Unresolved and no preview configured -> minimal safe payload (Business Rule 3).
    return dto;
  }

  /**
   * @description Assembles the account summary + four resilient tiles + announcement for a known
   * account. Shared by the real partner path and the internal-preview path so tile logic is
   * identical in both.
   * @param accountId the account whose data drives the tiles
   * @param summary the pre-built account summary (greeting + account line)
   * @param userId the running user (training progress is per-user)
   * @return the populated dashboard DTO
   */
  private hfs_HomeDashboardDTO buildForAccount(
    Id accountId,
    hfs_HomeDashboardDTO.AccountSummary summary,
    Id userId
  ) {
    hfs_HomeDashboardDTO dto = new hfs_HomeDashboardDTO();
    dto.accountSummary = summary;
    dto.tiles.add(buildActiveOrdersTile(accountId));
    dto.tiles.add(buildDownloadsTile(accountId));
    dto.tiles.add(buildTrainingTile(userId));
    dto.tiles.add(buildOpenRequestsTile(accountId));
    dto.announcement = buildAnnouncement('All');
    return dto;
  }

  /**
   * @description Test-only seam. When set, resolvePreviewAccount returns this account instead of
   * querying, so the internal-preview fallback can be covered deterministically in tests.
   */
  @TestVisible
  private static Account mockPreviewAccount;

  /**
   * @description Resolves the internal-preview Account from hfs_Home_Dashboard_Preview__mdt. Returns
   * null unless an active record names/identifies a real Account. Used ONLY for internal users with
   * no partner context; never called when a partner resolves.
   * @return the preview Account (with summary fields) or null
   */
  private Account resolvePreviewAccount() {
    if (Test.isRunningTest() && mockPreviewAccount != null) {
      return mockPreviewAccount;
    }
    hfs_Home_Dashboard_Preview__mdt config = hfs_Home_Dashboard_Preview__mdt.getInstance('Default');
    if (config == null || config.Enabled__c != true) {
      return null;
    }
    List<Account> accounts;
    if (String.isNotBlank(config.Preview_Account_Id__c)) {
      accounts = queryPreviewAccounts(
        'Id = :acctId',
        new Map<String, Object>{ 'acctId' => config.Preview_Account_Id__c.trim() }
      );
    } else if (String.isNotBlank(config.Preview_Account_Name__c)) {
      accounts = queryPreviewAccounts(
        'Name = :acctName',
        new Map<String, Object>{ 'acctName' => config.Preview_Account_Name__c.trim() }
      );
    } else {
      return null;
    }
    return accounts.isEmpty() ? null : accounts[0];
  }

  /**
   * @description Runs the preview-account lookup in system context. The preview is an internal QA
   * convenience, so it intentionally does not depend on the running admin holding partner sharing.
   * @param whereClause the bound WHERE clause
   * @param binds the bind variables
   * @return matching accounts (0 or 1)
   */
  private List<Account> queryPreviewAccounts(String whereClause, Map<String, Object> binds) {
    String query =
      'SELECT Id, Name, AccountNumber, ChannelProgramLevelName, BillingStreet, BillingCity, ' +
      'BillingState, BillingPostalCode FROM Account WHERE ' +
      whereClause +
      ' LIMIT 1';
    return (List<Account>) Database.queryWithBinds(query, binds, AccessLevel.SYSTEM_MODE);
  }

  /**
   * @description Test-only seam. When set, resolvePartner returns this user instead of querying,
   * so the tile success paths can be covered deterministically even where the org disallows
   * creating an external user in a test context.
   */
  @TestVisible
  private static User mockPartner;

  /**
   * @description Resolves the running user (with their Contact -> Account summary fields) via the
   * User -> Contact -> Account link, in the user's own context.
   * @param userId the signed-in user
   * @return the User with populated Contact.Account fields, or null when unresolved
   */
  private User resolvePartner(Id userId) {
    if (Test.isRunningTest() && mockPartner != null) {
      return mockPartner;
    }
    List<User> users = [
      SELECT
        FirstName,
        Contact.AccountId,
        Contact.Account.Name,
        Contact.Account.AccountNumber,
        Contact.Account.ChannelProgramLevelName,
        Contact.Account.BillingStreet,
        Contact.Account.BillingCity,
        Contact.Account.BillingState,
        Contact.Account.BillingPostalCode
      FROM User
      WHERE Id = :userId
      WITH USER_MODE
      LIMIT 1
    ];
    return users.isEmpty() ? null : users[0];
  }

  /**
   * @description Builds the greeting + account summary line values from the resolved user/account.
   * @param partner the resolved partner User (with Contact.Account fields)
   * @return the populated account summary DTO
   */
  private hfs_HomeDashboardDTO.AccountSummary buildAccountSummary(User partner) {
    return buildAccountSummary(partner.FirstName, partner.Contact.Account);
  }

  /**
   * @description Builds the greeting + account summary line from a greeting name and an Account.
   * Shared by the partner path (name from the User) and the internal-preview path (name from the
   * running internal user).
   * @param greetingName the first name to greet
   * @param acct the account whose summary fields populate the line
   * @return the populated account summary DTO
   */
  private hfs_HomeDashboardDTO.AccountSummary buildAccountSummary(String greetingName, Account acct) {
    hfs_HomeDashboardDTO.AccountSummary summary = new hfs_HomeDashboardDTO.AccountSummary();
    summary.greetingName = greetingName;
    summary.accountName = acct.Name;
    summary.accountNumber = acct.AccountNumber;
    summary.tier = acct.ChannelProgramLevelName;
    summary.addressLine = formatAddress(acct);
    return summary;
  }

  /**
   * @description Formats the billing address into a single line, skipping blank parts.
   * @param acct the partner Account
   * @return the formatted address line (may be blank)
   */
  private String formatAddress(Account acct) {
    List<String> parts = new List<String>();
    if (String.isNotBlank(acct.BillingStreet)) {
      parts.add(acct.BillingStreet);
    }
    if (String.isNotBlank(acct.BillingCity)) {
      parts.add(acct.BillingCity);
    }
    String stateZip = String.join(
      new List<String>{
        acct.BillingState == null ? '' : acct.BillingState,
        acct.BillingPostalCode == null ? '' : acct.BillingPostalCode
      },
      ' '
    ).trim();
    if (String.isNotBlank(stateZip)) {
      parts.add(stateZip);
    }
    return String.join(parts, ', ');
  }

  /**
   * @description Builds the Active Orders tile (Order Status = 'Activated'), resilient to failure.
   * @param accountId the partner account
   * @return the populated tile DTO
   */
  private hfs_HomeDashboardDTO.Tile buildActiveOrdersTile(Id accountId) {
    hfs_HomeDashboardDTO.Tile tile = new hfs_HomeDashboardDTO.Tile(
      TILE_ACTIVE_ORDERS,
      System.Label.hfs_HomeDashboard_TileActiveOrders,
      ACCENT_BLUE
    );
    try {
      throwIfForced();
      hfs_OrdersSelector selector = (hfs_OrdersSelector) hfs_Application.Selector.newInstance(
        Order.SObjectType
      );
      Integer count = selector.countOrderRecords(
        'AccountId = :accountId AND Status = :orderStatus',
        new Map<String, Object>{
          'accountId' => accountId,
          'orderStatus' => ORDER_ACTIVATED
        }
      );
      applyCount(tile, count);
    } catch (Exception e) {
      markUnavailable(tile);
    }
    return tile;
  }

  /**
   * @description Builds the Downloads This Month tile, resilient to failure. Supporting detail is
   * grouped by asset type.
   * @param accountId the partner account
   * @return the populated tile DTO
   */
  private hfs_HomeDashboardDTO.Tile buildDownloadsTile(Id accountId) {
    hfs_HomeDashboardDTO.Tile tile = new hfs_HomeDashboardDTO.Tile(
      TILE_DOWNLOADS,
      System.Label.hfs_HomeDashboard_TileDownloads,
      ACCENT_GREEN
    );
    try {
      throwIfForced();
      hfs_DownloadsSelector selector = (hfs_DownloadsSelector) hfs_Application.Selector.newInstance(
        hfs_Download__c.SObjectType
      );
      Datetime monthStart = Datetime.newInstance(
        Date.today().toStartOfMonth(),
        Time.newInstance(0, 0, 0, 0)
      );
      List<hfs_Download__c> downloads = selector.selectCurrentMonthByAccount(
        accountId,
        monthStart
      );
      applyCount(tile, downloads.size());
      tile.supportingDetail = buildTypeBreakdown(downloads);
    } catch (Exception e) {
      markUnavailable(tile);
    }
    return tile;
  }

  /**
   * @description Builds the Training Progress tile from the user's own progress rows, resilient
   * to failure. Value is "{completed} / {total} courses" with a computed progress percent.
   * @param userId the signed-in user
   * @return the populated tile DTO
   */
  private hfs_HomeDashboardDTO.Tile buildTrainingTile(Id userId) {
    hfs_HomeDashboardDTO.Tile tile = new hfs_HomeDashboardDTO.Tile(
      TILE_TRAINING,
      System.Label.hfs_HomeDashboard_TileTraining,
      ACCENT_AMBER
    );
    try {
      throwIfForced();
      hfs_CourseProgressSelector progressSelector = (hfs_CourseProgressSelector) hfs_Application.Selector.newInstance(
        hfs_CourseProgress__c.SObjectType
      );
      hfs_CoursesSelector coursesSelector = (hfs_CoursesSelector) hfs_Application.Selector.newInstance(
        hfs_Course__c.SObjectType
      );
      Integer totalCourses = coursesSelector.selectActiveCourses().size();
      Integer completed = 0;
      for (
        hfs_CourseProgress__c progress : progressSelector.selectByUser(userId)
      ) {
        if (STATUS_COMPLETED.equals(progress.hfs_Status__c)) {
          completed++;
        }
      }
      tile.value =
        completed +
        ' / ' +
        totalCourses +
        ' ' +
        System.Label.hfs_HomeDashboard_TrainingCoursesSuffix;
      tile.progressPercent = (totalCourses == 0)
        ? 0
        : Integer.valueOf(
            Math.round((Decimal.valueOf(completed) / totalCourses) * 100)
          );
      tile.status = (totalCourses == 0)
        ? hfs_HomeDashboardDTO.STATUS_EMPTY
        : hfs_HomeDashboardDTO.STATUS_OK;
    } catch (Exception e) {
      markUnavailable(tile);
    }
    return tile;
  }

  /**
   * @description Builds the Open Requests tile (Case Status != 'Closed'), resilient to failure.
   * Supporting detail is grouped by Status.
   * @param accountId the partner account
   * @return the populated tile DTO
   */
  private hfs_HomeDashboardDTO.Tile buildOpenRequestsTile(Id accountId) {
    hfs_HomeDashboardDTO.Tile tile = new hfs_HomeDashboardDTO.Tile(
      TILE_OPEN_REQUESTS,
      System.Label.hfs_HomeDashboard_TileOpenRequests,
      ACCENT_RED
    );
    try {
      throwIfForced();
      hfs_CasesSelector selector = (hfs_CasesSelector) hfs_Application.Selector.newInstance(
        Case.SObjectType
      );
      List<Case> cases = selector.selectOpenByAccount(accountId);
      applyCount(tile, cases.size());
      tile.supportingDetail = buildCaseStatusBreakdown(cases);
    } catch (Exception e) {
      markUnavailable(tile);
    }
    return tile;
  }

  /**
   * @description Reads the single active, highlighted announcement for the audience, resilient to
   * failure. Returns null when none active (banner absent).
   * @param audience the partner audience segment
   * @return the announcement DTO, or null
   */
  private hfs_HomeDashboardDTO.Announcement buildAnnouncement(String audience) {
    try {
      throwIfForced();
      hfs_AlertsSelector selector = (hfs_AlertsSelector) hfs_Application.Selector.newInstance(
        hfs_Alert__c.SObjectType
      );
      List<hfs_Alert__c> alerts = selector.selectActiveHighlighted(audience);
      if (alerts.isEmpty()) {
        return null;
      }
      hfs_Alert__c alert = alerts[0];
      hfs_HomeDashboardDTO.Announcement banner = new hfs_HomeDashboardDTO.Announcement();
      banner.title = alert.hfs_Title__c;
      banner.message = alert.hfs_Message__c;
      banner.ctaLabel = alert.hfs_CTA_Label__c;
      banner.ctaUrl = alert.hfs_CTA_URL__c;
      return banner;
    } catch (Exception e) {
      // A failed announcement read simply means no banner - never surface an error tile for it.
      return null;
    }
  }

  /**
   * @description Sets a numeric tile's value and OK/EMPTY status from a count.
   * @param tile the tile to populate
   * @param count the source count
   */
  private void applyCount(hfs_HomeDashboardDTO.Tile tile, Integer count) {
    tile.value = String.valueOf(count);
    tile.status = (count == 0)
      ? hfs_HomeDashboardDTO.STATUS_EMPTY
      : hfs_HomeDashboardDTO.STATUS_OK;
  }

  /**
   * @description Marks a tile UNAVAILABLE (source unreachable).
   * @param tile the tile to mark
   */
  private void markUnavailable(hfs_HomeDashboardDTO.Tile tile) {
    tile.status = hfs_HomeDashboardDTO.STATUS_UNAVAILABLE;
    tile.value = null;
  }

  /**
   * @description Builds the supporting-detail line for downloads, grouped by asset type.
   * @param downloads the current-month download rows
   * @return the "Logo files: n · Templates: n" style breakdown
   */
  private String buildTypeBreakdown(List<hfs_Download__c> downloads) {
    Map<String, Integer> countByType = new Map<String, Integer>();
    for (hfs_Download__c dl : downloads) {
      String type = String.isBlank(dl.hfs_Asset_Type__c)
        ? 'Other'
        : dl.hfs_Asset_Type__c;
      countByType.put(type, (countByType.containsKey(type) ? countByType.get(type) : 0) + 1);
    }
    List<String> parts = new List<String>();
    for (String type : countByType.keySet()) {
      parts.add(type + ': ' + countByType.get(type));
    }
    return String.join(parts, ' · ');
  }

  /**
   * @description Builds the supporting-detail line for open requests, grouped by Case Status.
   * @param cases the open Case rows
   * @return the "1 pending approval · 1 in review" style breakdown
   */
  private String buildCaseStatusBreakdown(List<Case> cases) {
    Map<String, Integer> countByStatus = new Map<String, Integer>();
    for (Case c : cases) {
      String status = String.isBlank(c.Status) ? 'Open' : c.Status;
      countByStatus.put(status, (countByStatus.containsKey(status) ? countByStatus.get(status) : 0) + 1);
    }
    List<String> parts = new List<String>();
    for (String status : countByStatus.keySet()) {
      parts.add(countByStatus.get(status) + ' ' + status);
    }
    return String.join(parts, ' · ');
  }

  /**
   * @description Throws inside a source's try block when the test seam is enabled, so the
   * resilience catch/UNAVAILABLE branch can be covered deterministically.
   */
  private void throwIfForced() {
    if (Test.isRunningTest() && forceFailure) {
      throw new hfs_HomeDashboardException('Forced test failure');
    }
  }

  /**
   * @description Local exception used only by the test-failure seam.
   */
  public class hfs_HomeDashboardException extends Exception {
  }
}