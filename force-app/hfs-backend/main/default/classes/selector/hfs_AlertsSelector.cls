/**
 * @description Selector for hfs_Alert__c. Centralizes the SOQL for the announcement banner on the
 * Home dashboard (HFS-32) and the unread-count badge in the global header (HFS-29). Alerts are
 * broadcast content (Public Read Only OWD) targeted by audience + active/date-window flags.
 * USER_MODE enforces CRUD/FLS at the query level so a user only ever sees their own scoped data.
 */
public inherited sharing class hfs_AlertsSelector extends fflib_SObjectSelector {
  /**
   * @description The SObject this selector queries.
   * @return hfs_Alert__c SObjectType.
   */
  public Schema.SObjectType getSObjectType() {
    return hfs_Alert__c.SObjectType;
  }

  /**
   * @description Base field list queried by the fflib base helpers.
   * @return The alert fields.
   */
  public List<Schema.SObjectField> getSObjectFieldList() {
    return new List<Schema.SObjectField>{
      hfs_Alert__c.Id,
      hfs_Alert__c.hfs_Title__c,
      hfs_Alert__c.hfs_Message__c,
      hfs_Alert__c.hfs_CTA_Label__c,
      hfs_Alert__c.hfs_CTA_URL__c,
      hfs_Alert__c.hfs_Is_Active__c,
      hfs_Alert__c.hfs_Is_Highlighted__c,
      hfs_Alert__c.hfs_Start_Date__c,
      hfs_Alert__c.hfs_End_Date__c,
      hfs_Alert__c.hfs_Audience__c
    };
  }

  /**
   * @description Returns the single active, highlighted alert whose optional date window is open
   * now and whose audience is 'All' or the supplied audience. Ordered newest first and capped at
   * one row, so at most one banner is shown.
   * @param audience the running partner's audience segment (may be null)
   * @return the matching active highlighted alerts (0 or 1 rows)
   */
  public List<hfs_Alert__c> selectActiveHighlighted(String audience) {
    Datetime nowDt = Datetime.now();
    String query =
      'SELECT Id, hfs_Title__c, hfs_Message__c, hfs_CTA_Label__c, hfs_CTA_URL__c ' +
      'FROM hfs_Alert__c ' +
      'WHERE hfs_Is_Active__c = true AND hfs_Is_Highlighted__c = true ' +
      'AND (hfs_Start_Date__c = null OR hfs_Start_Date__c <= :nowDt) ' +
      'AND (hfs_End_Date__c = null OR hfs_End_Date__c >= :nowDt) ' +
      'AND (hfs_Audience__c = \'All\' OR hfs_Audience__c = :audience) ' +
      'ORDER BY CreatedDate DESC ' +
      'LIMIT 1';
    return (List<hfs_Alert__c>) Database.queryWithBinds(
      query,
      new Map<String, Object>{ 'nowDt' => nowDt, 'audience' => audience },
      AccessLevel.USER_MODE
    );
  }

  /**
   * @description Count of active, in-window alerts that the given user has NOT dismissed - the
   * running user's own unread-alert count for the global-header badge (HFS-29).
   *
   * The per-user dismissal object (hfs_Alert_Dismissal__c) and the additional hfs_Alert__c
   * fields are owned by HFS-41 and are only partially present in this org today. The count is
   * therefore expressed as a fully dynamic SOQL string: when the dismissal object / fields are
   * absent the query throws at runtime, which the Controller catches and translates into an
   * UNAVAILABLE badge state (never 0, never a stale or another user's count). When HFS-41
   * delivers the model this method lights up with no change to its callers.
   *
   * USER_MODE enforces FLS/CRUD/sharing so the count is scoped to what the running user may see.
   * The bind map (no string concatenation of the user Id) keeps the query injection-safe.
   *
   * @param userId the running user's Id
   * @return the running user's own unread-alert count
   */
  public Integer countUnreadForUser(Id userId) {
    Datetime nowDt = Datetime.now();
    String query =
      'SELECT COUNT() FROM hfs_Alert__c ' +
      'WHERE hfs_Is_Active__c = true ' +
      'AND (hfs_Start_Date__c = null OR hfs_Start_Date__c <= :nowDt) ' +
      'AND (hfs_End_Date__c = null OR hfs_End_Date__c >= :nowDt) ' +
      'AND Id NOT IN (' +
      'SELECT hfs_Alert__c FROM hfs_Alert_Dismissal__c WHERE hfs_User__c = :userId' +
      ')';
    return Database.countQueryWithBinds(
      query,
      new Map<String, Object>{ 'nowDt' => nowDt, 'userId' => userId },
      AccessLevel.USER_MODE
    );
  }
}