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
}
