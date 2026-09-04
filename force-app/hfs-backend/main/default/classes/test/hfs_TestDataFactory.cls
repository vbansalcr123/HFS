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
   * @description Returns a unique suffix for building collision-free labels per run.
   * @return a unique string suffix
   */
  private static String uniqueSuffix() {
    return String.valueOf(Datetime.now().getTime()) +
      String.valueOf(Math.abs(Crypto.getRandomInteger()));
  }
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
   * other fields left null).
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
    return w;
  }

  /**
   * @description Builds a fully populated registration wrapper mirroring the request-access
   * form (company, name, phone, email, partner type, territory, message).
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
    return w;
  }
}
