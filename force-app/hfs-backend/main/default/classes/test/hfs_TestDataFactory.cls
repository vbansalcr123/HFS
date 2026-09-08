/**
 * @description Shared test data factory for the HFS package. All test data is created here rather
 * than inline per test. Records are built and (optionally) inserted for reuse across test classes.
 */
@IsTest
public class hfs_TestDataFactory {
  /**
   * @description Builds a list of active course records with representative categories.
   * @param count number of courses to build
   * @param doInsert whether to insert the records
   * @return the built (and optionally inserted) courses
   */
  public static List<hfs_Course__c> createCourses(
    Integer count,
    Boolean doInsert
  ) {
    List<String> categories = new List<String>{
      'Onboarding',
      'Brand & Standards',
      'Payment & Loyalty',
      'Site Operations',
      'Fuel & Products',
      'Compliance'
    };
    List<hfs_Course__c> courses = new List<hfs_Course__c>();
    for (Integer i = 0; i < count; i++) {
      courses.add(
        new hfs_Course__c(
          Name = 'Course ' + i,
          hfs_Category__c = categories[Math.mod(i, categories.size())],
          hfs_Description__c = 'Description for course ' + i,
          hfs_DurationMinutes__c = 30 + Math.mod(i, 5) * 5,
          hfs_ModuleCount__c = 3 + Math.mod(i, 4),
          hfs_IsActive__c = true,
          hfs_IsNewRelease__c = (Math.mod(i, 10) == 0)
        )
      );
    }
    if (doInsert) {
      insert courses;
    }
    return courses;
  }

  /**
   * @description Builds active course records that carry a content URL, so the HFS-34 launch guard
   * (active + content present) passes. Optionally inserts them.
   * @param count number of courses to build
   * @param doInsert whether to insert the records
   * @return the built (and optionally inserted) launchable courses
   */
  public static List<hfs_Course__c> createLaunchableCourses(
    Integer count,
    Boolean doInsert
  ) {
    List<hfs_Course__c> courses = createCourses(count, false);
    for (Integer i = 0; i < courses.size(); i++) {
      courses[i].hfs_ContentUrl__c = 'https://example.com/course/' + i;
    }
    if (doInsert) {
      insert courses;
    }
    return courses;
  }

  /**
   * @description Builds a progress record for a course and user.
   * @param courseId the course the progress belongs to
   * @param userId the owning user
   * @param status the status value
   * @param percent percent complete
   * @return the built progress record
   */
  public static hfs_CourseProgress__c createProgress(
    Id courseId,
    Id userId,
    String status,
    Integer percent
  ) {
    return new hfs_CourseProgress__c(
      hfs_Course__c = courseId,
      hfs_User__c = userId,
      hfs_Status__c = status,
      hfs_PercentComplete__c = percent,
      hfs_CurrentModule__c = (status == 'In Progress') ? 2 : null,
      hfs_CompletionDate__c = (status == 'Completed')
        ? Date.today().addDays(-10)
        : null,
      hfs_LastAccessedDate__c = (status == 'In Progress')
        ? Datetime.now()
        : null,
      hfs_CertificateUrl__c = (status == 'Completed')
        ? 'https://example.com/cert'
        : null
    );
  }

  /**
   * @description Builds an attempt record for a progress record (HFS-34).
   * @param progressId the parent progress record Id
   * @param attemptNumber the sequential attempt number
   * @param status the attempt status
   * @return the built attempt record
   */
  public static hfs_CourseAttempt__c createAttempt(
    Id progressId,
    Integer attemptNumber,
    String status
  ) {
    return new hfs_CourseAttempt__c(
      hfs_CourseProgress__c = progressId,
      hfs_AttemptNumber__c = attemptNumber,
      hfs_Status__c = status,
      hfs_StartedDate__c = Datetime.now(),
      hfs_PercentComplete__c = (status == 'Completed') ? 100 : 40,
      hfs_CompletionDate__c = (status == 'Completed') ? Date.today() : null,
      hfs_CertificateUrl__c = (status == 'Completed')
        ? 'https://example.com/cert/' + attemptNumber
        : null
    );
  }

  /**
   * @description Returns a unique suffix for building collision-free labels per run.
   * @return a unique string suffix
   */
  private static String uniqueSuffix() {
    return String.valueOf(Datetime.now().getTime()) +
      String.valueOf(Math.abs(Crypto.getRandomInteger()));
  }
  /**
   * @description Create and insert active favourite rows.
   * @param count Number of favourites to create.
   * @return The inserted favourites.
   */
  public static List<hfs_Favorite__c> createFavourites(Integer count) {
    List<hfs_Favorite__c> favourites = new List<hfs_Favorite__c>();
    for (Integer i = 0; i < count; i++) {
      favourites.add(
        new hfs_Favorite__c(
          Name = 'Favourite ' + i,
          hfs_Target_URL__c = 'https://example.com/asset/' + i,
          hfs_Icon__c = 'utility:favorite',
          hfs_Sort_Order__c = i,
          hfs_Item_Type__c = 'Asset'
        )
      );
    }
    insert favourites;
    return favourites;
  }

  /**
   * @description Create and insert active program catalog rows.
   * @param count Number of programs to create.
   * @return The inserted programs.
   */
  public static List<hfs_Program__c> createPrograms(Integer count) {
    List<hfs_Program__c> programs = new List<hfs_Program__c>();
    for (Integer i = 0; i < count; i++) {
      programs.add(
        new hfs_Program__c(
          Name = 'Program ' + i,
          hfs_Program_Key__c = 'Program ' + i,
          hfs_Destination_URL__c = 'https://example.com/program/' + i,
          hfs_Icon__c = 'utility:activity',
          hfs_Sort_Order__c = i,
          hfs_Active__c = true
        )
      );
    }
    insert programs;
    return programs;
  }

  /**
   * @description Enrol a member into the given programs (Status = Enrolled).
   * @param programs Programs to enrol into.
   * @param memberId The User to enrol.
   * @return The inserted enrolment rows.
   */
  public static List<hfs_Program_Enrolment__c> createEnrolments(
    List<hfs_Program__c> programs,
    Id memberId
  ) {
    List<hfs_Program_Enrolment__c> enrolments = new List<hfs_Program_Enrolment__c>();
    for (hfs_Program__c program : programs) {
      enrolments.add(
        new hfs_Program_Enrolment__c(
          hfs_Program__c = program.Id,
          hfs_Member__c = memberId,
          hfs_Enrolment_Key__c = memberId + ':' + program.Id,
          hfs_Status__c = 'Enrolled'
        )
      );
    }
    insert enrolments;
    return enrolments;
  }

  /**
   * @description Builds a registration wrapper for the register phase (name + email only;
   * other fields left null). Sets a policy-compliant default password so callers that
   * exercise the active-User / chosen-password provisioning path don't need to set one.
   * @param name registrant name
   * @param email registrant email
   * @return the wrapper
   */
  public static hfs_RegistrationWrapper buildRegistrationWrapper(
    String name,
    String email
  ) {
    hfs_RegistrationWrapper w = new hfs_RegistrationWrapper();
    w.name = name;
    w.email = email;
    w.password = 'Test1234!@#$';
    return w;
  }

  /**
   * @description Builds a fully populated registration wrapper mirroring the request-access
   * form (company, name, phone, email, partner type, territory, message). Sets a
   * policy-compliant default password so callers that exercise the active-User /
   * chosen-password provisioning path don't need to set one.
   * @param company company / business name
   * @param name registrant name
   * @param phone phone number
   * @param email registrant email
   * @param partnerType partner type (Dealer / Distributor)
   * @param territory territory / state
   * @param message free-text note
   * @return the wrapper
   */
  public static hfs_RegistrationWrapper buildRegistrationWrapper(
    String company,
    String name,
    String phone,
    String email,
    String partnerType,
    String territory,
    String message
  ) {
    hfs_RegistrationWrapper w = new hfs_RegistrationWrapper();
    w.company = company;
    w.name = name;
    w.phone = phone;
    w.email = email;
    w.partnerType = partnerType;
    w.territory = territory;
    w.message = message;
    w.password = 'Test1234!@#$';
    return w;
  }

  /**
   * @description Creates an active internal owner User that HAS a UserRole, so
   * provisioning tests can exercise the portal-account happy path (Salesforce
   * requires the owner of a portal account to hold a role). Uses the running
   * user's profile to avoid a hard-coded profile dependency.
   * @return the inserted role-bearing owner User
   */
  public static User createRoleBearingOwner() {
    UserRole role = new UserRole(Name = 'hfs Test Owner Role ' + generateSuffix());
    insert role;

    User owner = new User(
      FirstName = 'HFS',
      LastName = 'Portal Owner',
      Alias = 'hfsown',
      Email = 'hfs.owner@example.com',
      Username = 'hfs.owner.' + generateSuffix() + '@example.com.hfs',
      CommunityNickname = 'hfsown' + generateSuffix(),
      ProfileId = UserInfo.getProfileId(),
      UserRoleId = role.Id,
      TimeZoneSidKey = 'America/Los_Angeles',
      LocaleSidKey = 'en_US',
      EmailEncodingKey = 'UTF-8',
      LanguageLocaleKey = 'en_US',
      IsActive = true
    );
    insert owner;
    return owner;
  }

  /**
   * @description Builds a config override pointing provisioning at the given
   * role-bearing owner, mirroring the deployed Default record's profile /
   * permission-set names.
   * @param ownerUsername username of the role-bearing owner
   * @return an in-memory config record for the test seam
   */
  public static hfs_Registration_Config__mdt buildConfigForOwner(String ownerUsername) {
    return new hfs_Registration_Config__mdt(
      Community_Plus_Profile_Name__c = 'Customer Community Plus User',
      Partner_Permission_Set_Name__c = 'hfs_Dry_Run_Partner',
      Portal_Account_Owner_Username__c = ownerUsername
    );
  }

  private static Integer counter = 0;

  /**
   * @description Returns a unique numeric suffix for building collision-free
   * usernames / labels within a single test run.
   * @return a unique string suffix
   */
  private static String generateSuffix() {
    counter++;
    return String.valueOf(Datetime.now().getTime()) + counter;
  }

  /**
   * @description Builds and inserts a partner Account.
   * @return the inserted Account
   */
  public static Account createAccount() {
    Account acct = new Account(
      Name = 'Partner Account ' + uniqueSuffix(),
      AccountNumber = 'SNC-' + Math.abs(Crypto.getRandomInteger()),
      BillingStreet = '2847 Colfax Ave',
      BillingCity = 'Denver',
      BillingState = 'CO',
      BillingPostalCode = '80205'
    );
    insert acct;
    return acct;
  }

  /**
   * @description Builds and inserts a Contact linked to the given Account.
   * @param accountId the account the contact belongs to
   * @return the inserted Contact
   */
  public static Contact createContact(Id accountId) {
    Contact con = new Contact(
      FirstName = 'John',
      LastName = 'Partner ' + uniqueSuffix(),
      Email = 'contact' + uniqueSuffix() + '@example.com',
      AccountId = accountId
    );
    insert con;
    return con;
  }

  /**
   * @description Builds and inserts Orders for the given account in the supplied status.
   * @param count number of orders to create
   * @param accountId the account the orders belong to
   * @param status the order status (e.g. 'Draft')
   * @return the inserted Orders
   */
  public static List<Order> createOrders(
    Integer count,
    Id accountId,
    String status
  ) {
    List<Order> orders = new List<Order>();
    for (Integer i = 0; i < count; i++) {
      orders.add(
        new Order(
          AccountId = accountId,
          Status = status,
          EffectiveDate = Date.today()
        )
      );
    }
    insert orders;
    return orders;
  }

  /**
   * @description Builds and inserts Cases for the given account in the supplied status.
   * @param count number of cases to create
   * @param accountId the account the cases belong to
   * @param status the case status (e.g. 'New')
   * @return the inserted Cases
   */
  public static List<Case> createCases(
    Integer count,
    Id accountId,
    String status
  ) {
    List<Case> cases = new List<Case>();
    for (Integer i = 0; i < count; i++) {
      cases.add(
        new Case(
          AccountId = accountId,
          Status = status,
          Subject = 'Request ' + i,
          Origin = 'Web'
        )
      );
    }
    insert cases;
    return cases;
  }

  /**
   * @description Builds and inserts current-month Download records for the given account and user.
   * @param count number of downloads to create
   * @param accountId the account the downloads belong to
   * @param userId the user who downloaded the assets
   * @return the inserted Downloads
   */
  public static List<hfs_Download__c> createDownloads(
    Integer count,
    Id accountId,
    Id userId
  ) {
    List<String> assetTypes = new List<String>{
      'Logo',
      'Template',
      'Doc',
      'Video'
    };
    List<hfs_Download__c> downloads = new List<hfs_Download__c>();
    for (Integer i = 0; i < count; i++) {
      downloads.add(
        new hfs_Download__c(
          hfs_Account__c = accountId,
          hfs_Downloaded_By__c = userId,
          hfs_Asset_Name__c = 'Asset ' + i,
          hfs_Asset_Type__c = assetTypes[Math.mod(i, assetTypes.size())],
          hfs_Download_Date__c = Datetime.now()
        )
      );
    }
    insert downloads;
    return downloads;
  }

  /**
   * @description Builds and inserts a single active, highlighted announcement alert for the given
   * audience with an open date window so it surfaces on the Home dashboard banner.
   * @param audience the audience segment (e.g. 'All')
   * @return the inserted Alert
   */
  public static hfs_Alert__c createActiveAlert(String audience) {
    hfs_Alert__c alert = new hfs_Alert__c(
      hfs_Title__c = 'Guide available',
      hfs_Message__c = 'Refreshed templates',
      hfs_CTA_Label__c = 'Download',
      hfs_CTA_URL__c = 'https://example.com/guide',
      hfs_Is_Active__c = true,
      hfs_Is_Highlighted__c = true,
      hfs_Start_Date__c = Datetime.now().addDays(-1),
      hfs_End_Date__c = Datetime.now().addDays(30),
      hfs_Audience__c = audience
    );
    insert alert;
    return alert;
  }
}