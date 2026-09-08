/**
 * @description Tests for hfs_TrainingController. Asserts directly on hfs_Response - isSuccess/payload
 * for the success path and isSuccess=false/errorMessage/errorCode for the failure path. The Service
 * is mocked so the Controller is tested in isolation. HFS-34 adds coverage for the five action
 * methods (Start / Resume / Complete / Retake / View Certificate) on both success and failure.
 */
@IsTest
private class hfs_TrainingControllerTest {
  /**
   * @description Success path - a mocked Service returns a view; the Controller wraps it in a
   * success hfs_Response with the wrapper as payload.
   */
  @IsTest
  static void getTraining_success_returnsWrappedView() {
    hfs_TrainingWrapper view = new hfs_TrainingWrapper();
    view.summary = new hfs_TrainingWrapper.Summary();
    view.summary.coursesTotal = 5;

    fflib_ApexMocks mocks = new fflib_ApexMocks();
    hfs_TrainingService service = (hfs_TrainingService) mocks.mock(
      hfs_TrainingService.class
    );
    mocks.startStubbing();
    mocks.when(service.buildTrainingView(fflib_Match.anyId())).thenReturn(view);
    mocks.stopStubbing();
    hfs_Application.Service.setMock(hfs_TrainingService.class, service);

    Test.startTest();
    hfs_Response response = hfs_TrainingController.getTraining();
    Test.stopTest();

    System.Assert.isTrue(
      response.isSuccess,
      'Success path returns isSuccess = true'
    );
    System.Assert.isNotNull(response.payload, 'Payload carries the view');
    hfs_TrainingWrapper payload = (hfs_TrainingWrapper) response.payload;
    System.Assert.areEqual(
      5,
      payload.summary.coursesTotal,
      'Payload is the mocked view'
    );
  }

  /**
   * @description Failure path - a mocked Service throws; the Controller catches and returns an
   * error hfs_Response with a safe message and code (not the raw exception).
   */
  @IsTest
  static void getTraining_serviceThrows_returnsErrorResponse() {
    fflib_ApexMocks mocks = new fflib_ApexMocks();
    hfs_TrainingService service = (hfs_TrainingService) mocks.mock(
      hfs_TrainingService.class
    );
    mocks.startStubbing();
    mocks.when(service.buildTrainingView(fflib_Match.anyId()))
      .thenThrow(new System.QueryException('boom'));
    mocks.stopStubbing();
    hfs_Application.Service.setMock(hfs_TrainingService.class, service);

    Test.startTest();
    hfs_Response response = hfs_TrainingController.getTraining();
    Test.stopTest();

    System.Assert.isFalse(
      response.isSuccess,
      'Failure path returns isSuccess = false'
    );
    System.Assert.areEqual(
      hfs_Constants.TRAINING_LOAD_FAILED,
      response.errorCode,
      'Unexpected error maps to the training load-failed code'
    );
    System.Assert.isNotNull(
      response.errorMessage,
      'A safe error message is present'
    );
  }

  /**
   * @description Success path for every action method - a mocked action Service returns a DTO; the
   * Controller wraps it in a success hfs_Response with the DTO as payload.
   */
  @IsTest
  static void actionMethods_success_returnWrappedDto() {
    hfs_TrainingWrapper.Course dto = new hfs_TrainingWrapper.Course();
    dto.status = 'In Progress';

    fflib_ApexMocks mocks = new fflib_ApexMocks();
    hfs_TrainingService service = (hfs_TrainingService) mocks.mock(
      hfs_TrainingService.class
    );
    mocks.startStubbing();
    mocks.when(service.startCourse(fflib_Match.anyId())).thenReturn(dto);
    mocks.when(service.resumeCourse(fflib_Match.anyId())).thenReturn(dto);
    mocks.when(service.completeCourse(fflib_Match.anyId())).thenReturn(dto);
    mocks.when(service.retakeCourse(fflib_Match.anyId())).thenReturn(dto);
    mocks.when(service.getCertificate(fflib_Match.anyId())).thenReturn(dto);
    mocks.stopStubbing();
    hfs_Application.Service.setMock(hfs_TrainingService.class, service);

    Id courseId = fakeId(hfs_Course__c.SObjectType, 1);

    Test.startTest();
    System.Assert.isTrue(
      hfs_TrainingController.startCourse(courseId).isSuccess,
      'Start returns success'
    );
    System.Assert.isTrue(
      hfs_TrainingController.resumeCourse(courseId).isSuccess,
      'Resume returns success'
    );
    System.Assert.isTrue(
      hfs_TrainingController.completeCourse(courseId).isSuccess,
      'Complete returns success'
    );
    System.Assert.isTrue(
      hfs_TrainingController.retakeCourse(courseId).isSuccess,
      'Retake returns success'
    );
    System.Assert.isTrue(
      hfs_TrainingController.getCertificate(courseId).isSuccess,
      'Get certificate returns success'
    );
    Test.stopTest();
  }

  /**
   * @description Failure path - a mocked action Service throws a business hfs_TrainingException; the
   * Controller surfaces its own error code (CONTENT_UNAVAILABLE), not the generic fallback.
   */
  @IsTest
  static void startCourse_contentUnavailable_surfacesOwnErrorCode() {
    fflib_ApexMocks mocks = new fflib_ApexMocks();
    hfs_TrainingService service = (hfs_TrainingService) mocks.mock(
      hfs_TrainingService.class
    );
    mocks.startStubbing();
    mocks.when(service.startCourse(fflib_Match.anyId()))
      .thenThrow(
        new hfs_TrainingException(
          hfs_Constants.CONTENT_UNAVAILABLE,
          'unavailable'
        )
      );
    mocks.stopStubbing();
    hfs_Application.Service.setMock(hfs_TrainingService.class, service);

    Test.startTest();
    hfs_Response response = hfs_TrainingController.startCourse(
      fakeId(hfs_Course__c.SObjectType, 2)
    );
    Test.stopTest();

    System.Assert.isFalse(
      response.isSuccess,
      'Failure returns isSuccess=false'
    );
    System.Assert.areEqual(
      hfs_Constants.CONTENT_UNAVAILABLE,
      response.errorCode,
      'Business exception surfaces its own error code (CONTENT_UNAVAILABLE)'
    );
  }

  /**
   * @description Failure path - an unexpected (non-business) exception falls back to the action
   * failure code PROGRESS_WRITE_FAILED.
   */
  @IsTest
  static void completeCourse_unexpectedError_usesFallbackCode() {
    fflib_ApexMocks mocks = new fflib_ApexMocks();
    hfs_TrainingService service = (hfs_TrainingService) mocks.mock(
      hfs_TrainingService.class
    );
    mocks.startStubbing();
    mocks.when(service.completeCourse(fflib_Match.anyId()))
      .thenThrow(new System.NullPointerException());
    mocks.stopStubbing();
    hfs_Application.Service.setMock(hfs_TrainingService.class, service);

    Test.startTest();
    hfs_Response response = hfs_TrainingController.completeCourse(
      fakeId(hfs_Course__c.SObjectType, 3)
    );
    Test.stopTest();

    System.Assert.isFalse(
      response.isSuccess,
      'Failure returns isSuccess=false'
    );
    System.Assert.areEqual(
      hfs_Constants.PROGRESS_WRITE_FAILED,
      response.errorCode,
      'Unexpected error uses the PROGRESS_WRITE_FAILED fallback'
    );
  }

  /**
   * @description Forces the service to throw for resumeCourse, retakeCourse and getCertificate so
   * each action method's catch branch (and its fallback error code) is exercised.
   */
  @IsTest
  static void remainingActionMethods_serviceThrows_returnErrorResponse() {
    fflib_ApexMocks mocks = new fflib_ApexMocks();
    hfs_TrainingService service = (hfs_TrainingService) mocks.mock(
      hfs_TrainingService.class
    );
    mocks.startStubbing();
    mocks.when(service.resumeCourse(fflib_Match.anyId()))
      .thenThrow(new System.NullPointerException());
    mocks.when(service.retakeCourse(fflib_Match.anyId()))
      .thenThrow(new System.NullPointerException());
    mocks.when(service.getCertificate(fflib_Match.anyId()))
      .thenThrow(new System.QueryException('boom'));
    mocks.stopStubbing();
    hfs_Application.Service.setMock(hfs_TrainingService.class, service);

    Id courseId = fakeId(hfs_Course__c.SObjectType, 7);

    Test.startTest();
    hfs_Response resumeResponse = hfs_TrainingController.resumeCourse(courseId);
    hfs_Response retakeResponse = hfs_TrainingController.retakeCourse(courseId);
    hfs_Response certResponse = hfs_TrainingController.getCertificate(courseId);
    Test.stopTest();

    System.Assert.isFalse(
      resumeResponse.isSuccess,
      'resumeCourse failure returns isSuccess = false'
    );
    System.Assert.areEqual(
      hfs_Constants.PROGRESS_WRITE_FAILED,
      resumeResponse.errorCode,
      'resumeCourse failure uses the PROGRESS_WRITE_FAILED fallback code'
    );
    System.Assert.isFalse(
      retakeResponse.isSuccess,
      'retakeCourse failure returns isSuccess = false'
    );
    System.Assert.areEqual(
      hfs_Constants.PROGRESS_WRITE_FAILED,
      retakeResponse.errorCode,
      'retakeCourse failure uses the PROGRESS_WRITE_FAILED fallback code'
    );
    System.Assert.isFalse(
      certResponse.isSuccess,
      'getCertificate failure returns isSuccess = false'
    );
    System.Assert.areEqual(
      hfs_Constants.NO_CERTIFICATE,
      certResponse.errorCode,
      'getCertificate failure uses the NO_CERTIFICATE error code'
    );
  }

  /**
   * @description Covers the application exception carrier and the constants holder so
   * these low-logic classes contribute to org-wide coverage.
   */
  @IsTest
  static void applicationException_carriesErrorCode() {
    Test.startTest();
    hfs_ApplicationException ex = new hfs_ApplicationException();
    ex.setMessage('boom');
    ex.setErrorCode(hfs_Constants.TRAINING_LOAD_FAILED);
    Test.stopTest();

    System.Assert.areEqual(
      hfs_Constants.TRAINING_LOAD_FAILED,
      ex.errorCode,
      'Error code should be carried by the exception'
    );
  }

  // ---------------------------------------------------------------------------------------------
  // Certificate Visualforce page controller tests (hfs_TrainingCertificate page)
  // ---------------------------------------------------------------------------------------------

  /**
   * @description Owned + completed course: the controller resolves the certificate context for the
   * signed-in user and sets hasCertificate = true.
   */
  @IsTest
  static void certificate_ownedCompleted_resolvesCertificate() {
    User certUser = makeCertificateTestUser();
    hfs_Course__c course = hfs_TestDataFactory.createLaunchableCourses(
      1,
      true
    )[0];
    hfs_CourseProgress__c progress = hfs_TestDataFactory.createProgress(
      course.Id,
      certUser.Id,
      'Completed',
      100
    );
    progress.hfs_AttemptNumber__c = 1;
    progress.hfs_CertificateUrl__c =
      '/apex/hfs_TrainingCertificate?courseId=' + course.Id;
    insert progress;

    Test.startTest();
    hfs_TrainingController ctrl;
    System.runAs(certUser) {
      PageReference ref = Page.hfs_TrainingCertificate;
      ref.getParameters().put('courseId', course.Id);
      Test.setCurrentPage(ref);
      ctrl = new hfs_TrainingController();
    }
    Test.stopTest();

    System.Assert.isTrue(
      ctrl.hasCertificate,
      'A completed, owned course resolves a certificate'
    );
    System.Assert.areEqual(
      course.Id,
      ctrl.courseId,
      'Course Id is resolved from the page parameter'
    );
    System.Assert.isNotNull(
      ctrl.certificate,
      'The certificate view (hfs_TrainingWrapper.Course) is resolved'
    );
    System.Assert.isNotNull(
      ctrl.certificate.certificateUrl,
      'The certificate URL is carried on the wrapper'
    );
  }

  /**
   * @description No course parameter: the controller stays in the no-certificate state.
   */
  @IsTest
  static void certificate_noParam_hasNoCertificate() {
    Test.startTest();
    PageReference ref = Page.hfs_TrainingCertificate;
    Test.setCurrentPage(ref);
    hfs_TrainingController ctrl = new hfs_TrainingController();
    Test.stopTest();

    System.Assert.isFalse(
      ctrl.hasCertificate,
      'No course parameter yields no certificate'
    );
  }

  /**
   * @description A course the user has no completed progress for stays in the no-certificate state
   * (no data leak).
   */
  @IsTest
  static void certificate_notOwned_hasNoCertificate() {
    User certUser = makeCertificateTestUser();
    hfs_Course__c course = hfs_TestDataFactory.createLaunchableCourses(
      1,
      true
    )[0];

    Test.startTest();
    hfs_TrainingController ctrl;
    System.runAs(certUser) {
      PageReference ref = Page.hfs_TrainingCertificate;
      ref.getParameters().put('courseId', course.Id);
      Test.setCurrentPage(ref);
      ctrl = new hfs_TrainingController();
    }
    Test.stopTest();

    System.Assert.isFalse(
      ctrl.hasCertificate,
      'No owned completed progress yields no certificate'
    );
  }

  /**
   * @description An invalid (non-Id) courseId parameter is handled gracefully with no certificate.
   */
  @IsTest
  static void certificate_invalidCourseParam_hasNoCertificate() {
    Test.startTest();
    PageReference ref = Page.hfs_TrainingCertificate;
    ref.getParameters().put('courseId', 'not-a-valid-id');
    Test.setCurrentPage(ref);
    hfs_TrainingController ctrl = new hfs_TrainingController();
    Test.stopTest();

    System.Assert.isFalse(
      ctrl.hasCertificate,
      'An invalid course parameter yields no certificate'
    );
  }

  /**
   * @description Creates a Standard User and grants Read + field FLS on the Course/Progress
   * fields the certificate page controller's USER_MODE selector queries, via a test-only
   * PermissionSet built entirely in Apex (there is no packaged "training access" permission set
   * for this feature yet). Metadata-deployed custom fields grant no profile FLS by default, not
   * even to the org's admin. Setup-object DML (User/PermissionSet/*Permissions/
   * PermissionSetAssignment) is isolated in its own runAs so it doesn't collide with the caller's
   * own hfs_Course__c/hfs_CourseProgress__c DML in the same transaction.
   * @return the inserted user with the permission set assigned
   */
  private static User makeCertificateTestUser() {
    Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
    String unique = String.valueOf(Datetime.now().getTime());
    User u = new User(
      FirstName = 'HFS',
      LastName = 'CertTester',
      Alias = 'hfsct',
      Email = 'hfs.cert.tester@example.com',
      Username = 'hfs.cert.tester.' + unique + '@example.com.invalid',
      EmailEncodingKey = 'UTF-8',
      LanguageLocaleKey = 'en_US',
      LocaleSidKey = 'en_US',
      TimeZoneSidKey = 'America/Los_Angeles',
      ProfileId = p.Id
    );

    System.runAs(new User(Id = UserInfo.getUserId())) {
      insert u;

      PermissionSet ps = new PermissionSet(
        Name = 'hfs_CertTestAccess',
        Label = 'HFS Certificate Test Access'
      );
      insert ps;

      insert new List<ObjectPermissions>{
        new ObjectPermissions(
          ParentId = ps.Id,
          SObjectType = 'hfs_Course__c',
          PermissionsRead = true
        ),
        new ObjectPermissions(
          ParentId = ps.Id,
          SObjectType = 'hfs_CourseProgress__c',
          PermissionsRead = true
        )
      };

      // hfs_Category__c/hfs_Status__c are required (always visible with object access), and
      // hfs_CourseProgress__c.hfs_TotalAttempts__c is a roll-up summary (non-permissionable) -
      // none of the three accept a FieldPermissions row.
      List<String> readableFields = new List<String>{
        'hfs_Course__c.hfs_Description__c',
        'hfs_Course__c.hfs_DurationMinutes__c',
        'hfs_Course__c.hfs_ModuleCount__c',
        'hfs_Course__c.hfs_DueDate__c',
        'hfs_Course__c.hfs_IsNewRelease__c',
        'hfs_Course__c.hfs_ReleasedDate__c',
        'hfs_Course__c.hfs_IsActive__c',
        'hfs_Course__c.hfs_ContentUrl__c',
        'hfs_CourseProgress__c.hfs_User__c',
        'hfs_CourseProgress__c.hfs_PercentComplete__c',
        'hfs_CourseProgress__c.hfs_CurrentModule__c',
        'hfs_CourseProgress__c.hfs_CompletionDate__c',
        'hfs_CourseProgress__c.hfs_CertificateUrl__c',
        'hfs_CourseProgress__c.hfs_LastAccessedDate__c',
        'hfs_CourseProgress__c.hfs_AttemptNumber__c',
        'hfs_CourseProgress__c.hfs_CurrentAttempt__c'
      };
      List<FieldPermissions> fps = new List<FieldPermissions>();
      for (String field : readableFields) {
        fps.add(
          new FieldPermissions(
            ParentId = ps.Id,
            SObjectType = field.substringBefore('.'),
            Field = field,
            PermissionsRead = true,
            PermissionsEdit = false
          )
        );
      }
      insert fps;

      insert new PermissionSetAssignment(
        AssigneeId = u.Id,
        PermissionSetId = ps.Id
      );
    }
    return u;
  }

  /**
   * @description Builds a deterministic fake Id for the given SObjectType.
   * @param sot the SObjectType
   * @param index a positive integer to vary the Id
   * @return a syntactically valid Id
   */
  private static Id fakeId(Schema.SObjectType sot, Integer index) {
    String prefix = sot.getDescribe().getKeyPrefix();
    String suffix = String.valueOf(index);
    return Id.valueOf(prefix + '0'.repeat(12 - suffix.length()) + suffix);
  }
}
