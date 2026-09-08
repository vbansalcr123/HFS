/**
 * @description Controller for the Training Library page. Thin boundary between the LWC and the
 * Service layer: each @AuraEnabled method calls exactly one Service method, wraps success in
 * hfs_Response.success(...) and any exception in hfs_Response.error(...). Reads are cacheable; the
 * HFS-34 action methods are plain (non-cacheable) writes. This class also backs the
 * Salesforce-rendered training certificate Visualforce page (hfs_TrainingCertificate): the page
 * constructor resolves the certificate context for the signed-in user only and carries it on the
 * existing hfs_TrainingWrapper.Course view. Declared with sharing as a UI entry point.
 */
public with sharing class hfs_TrainingController {
  // ---------------------------------------------------------------------------------------------
  // Visualforce page controller members (hfs_TrainingCertificate page)
  // ---------------------------------------------------------------------------------------------

  /** The course Id passed in the page parameters. */
  public Id courseId { get; private set; }

  /**
   * The resolved certificate view, carried on the existing training view wrapper
   * (hfs_TrainingWrapper.Course). The page renders certificate.title / certificate.completionDate /
   * certificate.certificateUrl from this shape rather than from bespoke controller getters.
   */
  public hfs_TrainingWrapper.Course certificate { get; private set; }

  /** True when a valid, owned, completed certificate could be resolved (the wrapper has no flag). */
  public Boolean hasCertificate {
    get {
      return this.certificate != null &&
        String.isNotBlank(this.certificate.certificateUrl);
    }
  }

  /**
   * @description Resolves the certificate context from page parameters for the signed-in user only.
   * If the user does not own a completed progress record for the course, certificate stays null (so
   * hasCertificate is false) and the page shows a no-data message rather than exposing any other
   * user's data. Re-resolves the record via the own-data selector (USER_MODE, pinned to
   * UserInfo.getUserId()) rather than trusting the Id in the URL, so there is no direct-Id path to
   * another user's certificate. The resolved data is carried on the existing hfs_TrainingWrapper.Course.
   */
  public hfs_TrainingController() {
    String courseParam = ApexPages.currentPage()
      .getParameters()
      .get('courseId');
    if (String.isBlank(courseParam)) {
      return;
    }

    try {
      this.courseId = (Id) courseParam;
    } catch (Exception e) {
      return;
    }

    hfs_CourseProgressSelector progressSelector = (hfs_CourseProgressSelector) hfs_Application.Selector.newInstance(
      hfs_CourseProgress__c.SObjectType
    );
    List<hfs_CourseProgress__c> owned = progressSelector.selectByUserAndCourse(
      UserInfo.getUserId(),
      this.courseId
    );
    if (owned.isEmpty() || String.isBlank(owned[0].hfs_CertificateUrl__c)) {
      return;
    }

    hfs_CourseProgress__c progress = owned[0];

    hfs_CoursesSelector coursesSelector = (hfs_CoursesSelector) hfs_Application.Selector.newInstance(
      hfs_Course__c.SObjectType
    );
    List<hfs_Course__c> courses = coursesSelector.selectById(this.courseId);

    hfs_TrainingWrapper.Course cert = new hfs_TrainingWrapper.Course();
    cert.id = this.courseId;
    cert.title = courses.isEmpty() ? '' : courses[0].Name;
    cert.status = 'Completed';
    cert.completionDate = progress.hfs_CompletionDate__c;
    cert.certificateUrl = progress.hfs_CertificateUrl__c;
    this.certificate = cert;
  }

  // ---------------------------------------------------------------------------------------------
  // LWC controller methods (Training Library page)
  // ---------------------------------------------------------------------------------------------

  /**
   * @description Builds the training view (progress summary + course cards) for the signed-in user.
   * @return an hfs_Response whose payload is the hfs_TrainingWrapper view on success
   */
  @AuraEnabled(cacheable=true)
  public static hfs_Response getTraining() {
    try {
      hfs_TrainingService service = (hfs_TrainingService) hfs_Application.Service.newInstance(
        hfs_TrainingService.class
      );
      return hfs_Response.success(
        service.buildTrainingView(UserInfo.getUserId())
      );
    } catch (Exception e) {
      return hfs_Response.error(
        e,
        hfs_Constants.TRAINING_LOAD_FAILED,
        System.Label.hfs_Error_Training_Load_Failed
      );
    }
  }

  /**
   * @description Starts a Not Started course for the signed-in user (HFS-34).
   * @param courseId the course to start
   * @return an hfs_Response whose payload is the hfs_TrainingWrapper.Course on success
   */
  @AuraEnabled
  public static hfs_Response startCourse(Id courseId) {
    try {
      return hfs_Response.success(actionService().startCourse(courseId));
    } catch (Exception e) {
      return hfs_Response.error(
        e,
        hfs_Constants.PROGRESS_WRITE_FAILED,
        System.Label.hfs_Error_Training_Action_Failed
      );
    }
  }

  /**
   * @description Resumes an In Progress course for the signed-in user (HFS-34).
   * @param courseId the course to resume
   * @return an hfs_Response whose payload is the hfs_TrainingWrapper.Course on success
   */
  @AuraEnabled
  public static hfs_Response resumeCourse(Id courseId) {
    try {
      return hfs_Response.success(actionService().resumeCourse(courseId));
    } catch (Exception e) {
      return hfs_Response.error(
        e,
        hfs_Constants.PROGRESS_WRITE_FAILED,
        System.Label.hfs_Error_Training_Action_Failed
      );
    }
  }

  /**
   * @description Completes the signed-in user's current attempt at a course (HFS-34).
   * @param courseId the course to complete
   * @return an hfs_Response whose payload is the hfs_TrainingWrapper.Course on success
   */
  @AuraEnabled
  public static hfs_Response completeCourse(Id courseId) {
    try {
      return hfs_Response.success(actionService().completeCourse(courseId));
    } catch (Exception e) {
      return hfs_Response.error(
        e,
        hfs_Constants.PROGRESS_WRITE_FAILED,
        System.Label.hfs_Error_Training_Action_Failed
      );
    }
  }

  /**
   * @description Retakes a Completed course for the signed-in user, preserving history (HFS-34).
   * @param courseId the course to retake
   * @return an hfs_Response whose payload is the hfs_TrainingWrapper.Course on success
   */
  @AuraEnabled
  public static hfs_Response retakeCourse(Id courseId) {
    try {
      return hfs_Response.success(actionService().retakeCourse(courseId));
    } catch (Exception e) {
      return hfs_Response.error(
        e,
        hfs_Constants.PROGRESS_WRITE_FAILED,
        System.Label.hfs_Error_Training_Action_Failed
      );
    }
  }

  /**
   * @description Returns the certificate URL for the signed-in user's completed attempt (HFS-34).
   * @param courseId the course whose certificate is required
   * @return an hfs_Response whose payload is the hfs_TrainingWrapper.Course carrying the certificate URL
   */
  @AuraEnabled
  public static hfs_Response getCertificate(Id courseId) {
    try {
      return hfs_Response.success(actionService().getCertificate(courseId));
    } catch (Exception e) {
      return hfs_Response.error(
        e,
        hfs_Constants.NO_CERTIFICATE,
        System.Label.hfs_Error_Training_Action_Failed
      );
    }
  }

  /**
   * @description Resolves the Training service through the Application factory.
   * @return the Training service instance
   */
  private static hfs_TrainingService actionService() {
    return (hfs_TrainingService) hfs_Application.Service.newInstance(
      hfs_TrainingService.class
    );
  }
}
