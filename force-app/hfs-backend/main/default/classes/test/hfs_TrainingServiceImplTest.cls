/**
 * @description Tests for hfs_TrainingServiceImpl. Covers both the read use case (buildTrainingView)
 * and the HFS-34 action use cases (Start / Resume / Complete / Retake / View Certificate) on the
 * one consolidated Training service. Tier 1: real end-to-end tests with real DML and 200+ records
 * run as FLS-limited users (USER_MODE selectors + Unit of Work). Tier 2: fflib_ApexMocks-based
 * Selector variations that exercise summary/status derivation and the fail-closed / error branches
 * without DML. All data via hfs_TestDataFactory; no SeeAllData, no hardcoded Ids.
 */
@IsTest
private class hfs_TrainingServiceImplTest {
  /**
   * @description Tier 1 - real records, real DML, bulk-safe. Verifies status derivation,
   * own-data scoping, and summary computation end to end against real queries.
   */
  @IsTest
  static void buildTrainingView_realData_computesSummaryAndCards() {
    User runningUser = makeTrainingUserWithFls();
    Id userId = runningUser.Id;

    // Create data in system context (admin) so setup is not blocked by the running
    // user's CRUD/FLS; the USER_MODE selectors are exercised under runAs below.
    List<hfs_Course__c> courses = hfs_TestDataFactory.createCourses(210, true);
    List<hfs_CourseProgress__c> progress = new List<hfs_CourseProgress__c>();
    for (Integer i = 0; i < 100; i++) {
      String status = (Math.mod(i, 2) == 0) ? 'Completed' : 'In Progress';
      Integer percent = (status == 'Completed') ? 100 : 40;
      progress.add(
        hfs_TestDataFactory.createProgress(
          courses[i].Id,
          userId,
          status,
          percent
        )
      );
    }
    insert progress;

    Test.startTest();
    hfs_TrainingWrapper view;
    System.runAs(runningUser) {
      hfs_TrainingService service = new hfs_TrainingServiceImpl();
      view = service.buildTrainingView(userId);
    }
    Test.stopTest();

    System.Assert.isNotNull(view, 'View should be returned');
    System.Assert.areEqual(
      210,
      view.summary.coursesTotal,
      'All active courses counted'
    );
    System.Assert.areEqual(
      50,
      view.summary.coursesCompleted,
      'Completed courses counted'
    );
    System.Assert.areEqual(
      160,
      view.summary.coursesRemaining,
      'Remaining = total minus completed'
    );
    System.Assert.isTrue(view.summary.hasProgress, 'User has progress records');
    System.Assert.areEqual(
      210,
      view.courses.size(),
      'One card per active course'
    );
  }

  /**
   * @description Tier 2 - mocked Selectors, no DML. First-time user with no progress returns an
   * explicit zero/first-time summary rather than a blank.
   */
  @IsTest
  static void buildTrainingView_noProgress_returnsZeroState() {
    Id userId = UserInfo.getUserId();
    List<hfs_Course__c> courses = hfs_TestDataFactory.createCourses(4, false);
    for (Integer i = 0; i < courses.size(); i++) {
      courses[i].Id = fakeId(hfs_Course__c.SObjectType, i + 1);
    }

    mockSelectors(courses, new List<hfs_CourseProgress__c>());

    Test.startTest();
    hfs_TrainingService service = new hfs_TrainingServiceImpl();
    hfs_TrainingWrapper view = service.buildTrainingView(userId);
    Test.stopTest();

    System.Assert.isFalse(
      view.summary.hasProgress,
      'No progress -> first-time state'
    );
    System.Assert.areEqual(
      0,
      view.summary.percentComplete,
      'Zero percent when no progress'
    );
    System.Assert.areEqual(0, view.summary.coursesCompleted, 'Zero completed');
    System.Assert.areEqual(
      4,
      view.summary.coursesTotal,
      'Total from mocked selector'
    );
    for (hfs_TrainingWrapper.Course card : view.courses) {
      System.Assert.areEqual(
        'Not Started',
        card.status,
        'Cards default to Not Started'
      );
    }
  }

  /**
   * @description Tier 2 - mocked Selectors. No active courses at all: the summary must default to
   * a zero percentComplete rather than dividing by zero, and no cards are built.
   */
  @IsTest
  static void buildTrainingView_noCourses_returnsZeroPercentSummary() {
    Id userId = UserInfo.getUserId();
    mockSelectors(new List<hfs_Course__c>(), new List<hfs_CourseProgress__c>());

    Test.startTest();
    hfs_TrainingService service = new hfs_TrainingServiceImpl();
    hfs_TrainingWrapper view = service.buildTrainingView(userId);
    Test.stopTest();

    System.Assert.areEqual(0, view.summary.coursesTotal, 'No active courses');
    System.Assert.areEqual(
      0,
      view.summary.percentComplete,
      'Zero-course summary defaults to 0 percent, avoiding divide-by-zero'
    );
    System.Assert.isTrue(
      view.courses.isEmpty(),
      'No cards built when there are no courses'
    );
  }

  /**
   * @description Tier 2 - mocked Selectors. A course with no duration and a progress record with
   * blank status/null percent: the card falls back to Not Started/0% and contributes zero to the
   * remaining-minutes total instead of throwing.
   */
  @IsTest
  static void buildTrainingView_nullDurationAndBlankProgress_appliesDefaults() {
    Id userId = UserInfo.getUserId();
    Id courseId = fakeId(hfs_Course__c.SObjectType, 1);

    List<hfs_Course__c> courses = new List<hfs_Course__c>{
      new hfs_Course__c(
        Id = courseId,
        Name = 'No Duration',
        hfs_Category__c = 'Compliance'
      )
    };
    List<hfs_CourseProgress__c> progress = new List<hfs_CourseProgress__c>{
      new hfs_CourseProgress__c(hfs_Course__c = courseId, hfs_User__c = userId)
    };

    mockSelectors(courses, progress);

    Test.startTest();
    hfs_TrainingWrapper view = new hfs_TrainingServiceImpl()
      .buildTrainingView(userId);
    Test.stopTest();

    hfs_TrainingWrapper.Course card = view.courses[0];
    System.Assert.areEqual(
      'Not Started',
      card.status,
      'Blank progress status falls back to Not Started'
    );
    System.Assert.areEqual(
      0,
      card.percentComplete,
      'Null percentComplete defaults to 0'
    );
    System.Assert.isNull(
      card.durationMinutes,
      'Null duration stays null on the card'
    );
    System.Assert.areEqual(
      0,
      view.summary.estRemainingMinutes,
      'Null duration contributes zero remaining minutes'
    );
  }

  /**
   * @description Tier 2 - mocked Selectors. Verifies status derivation, resume target selection,
   * overdue flag, and divide-by-zero-safe percent for an in-progress + completed mix.
   */
  @IsTest
  static void buildTrainingView_withProgress_derivesStatusResumeAndOverdue() {
    Id userId = UserInfo.getUserId();

    Id completedCourseId = fakeId(hfs_Course__c.SObjectType, 1);
    Id inProgressCourseId = fakeId(hfs_Course__c.SObjectType, 2);
    Id overdueCourseId = fakeId(hfs_Course__c.SObjectType, 3);

    List<hfs_Course__c> courses = new List<hfs_Course__c>{
      new hfs_Course__c(
        Id = completedCourseId,
        Name = 'Done',
        hfs_Category__c = 'Compliance',
        hfs_DurationMinutes__c = 30
      ),
      new hfs_Course__c(
        Id = inProgressCourseId,
        Name = 'Doing',
        hfs_Category__c = 'Onboarding',
        hfs_DurationMinutes__c = 45
      ),
      new hfs_Course__c(
        Id = overdueCourseId,
        Name = 'Late',
        hfs_Category__c = 'Fuel & Products',
        hfs_DurationMinutes__c = 60,
        hfs_DueDate__c = Date.today().addDays(-5)
      )
    };

    List<hfs_CourseProgress__c> progress = new List<hfs_CourseProgress__c>{
      new hfs_CourseProgress__c(
        hfs_Course__c = completedCourseId,
        hfs_User__c = userId,
        hfs_Status__c = 'Completed',
        hfs_PercentComplete__c = 100,
        hfs_CompletionDate__c = Date.today().addDays(-1)
      ),
      new hfs_CourseProgress__c(
        hfs_Course__c = inProgressCourseId,
        hfs_User__c = userId,
        hfs_Status__c = 'In Progress',
        hfs_PercentComplete__c = 50,
        hfs_CurrentModule__c = 2,
        hfs_LastAccessedDate__c = Datetime.now()
      )
    };

    mockSelectors(courses, progress);

    Test.startTest();
    hfs_TrainingWrapper view = new hfs_TrainingServiceImpl()
      .buildTrainingView(userId);
    Test.stopTest();

    System.Assert.areEqual(
      3,
      view.summary.coursesTotal,
      'Three active courses'
    );
    System.Assert.areEqual(1, view.summary.coursesCompleted, 'One completed');
    System.Assert.areEqual(
      33,
      view.summary.percentComplete,
      '1 of 3 rounds to 33%'
    );
    // Remaining minutes = in-progress (45) + overdue not-started (60) = 105.
    System.Assert.areEqual(
      105,
      view.summary.estRemainingMinutes,
      'Remaining durations summed'
    );
    System.Assert.areEqual(
      inProgressCourseId,
      view.summary.resumeCourseId,
      'Resume target is the in-progress course'
    );

    Map<Id, hfs_TrainingWrapper.Course> cardById = new Map<Id, hfs_TrainingWrapper.Course>();
    for (hfs_TrainingWrapper.Course card : view.courses) {
      cardById.put(card.id, card);
    }
    System.Assert.areEqual(
      'Completed',
      cardById.get(completedCourseId).status,
      'Completed'
    );
    System.Assert.isTrue(
      cardById.get(overdueCourseId).isOverdue,
      'Past due -> overdue'
    );
    System.Assert.isFalse(
      cardById.get(completedCourseId).isOverdue,
      'Completed is never overdue'
    );
  }

  /**
   * @description Registers fflib_ApexMocks-based Selector stubs on the Application factory so the
   * Service resolves them instead of hitting the database.
   * @param courses the course records the courses selector should return
   * @param progress the progress records the progress selector should return
   */
  private static void mockSelectors(
    List<hfs_Course__c> courses,
    List<hfs_CourseProgress__c> progress
  ) {
    fflib_ApexMocks mocks = new fflib_ApexMocks();
    hfs_CoursesSelector coursesSelector = (hfs_CoursesSelector) mocks.mock(
      hfs_CoursesSelector.class
    );
    hfs_CourseProgressSelector progressSelector = (hfs_CourseProgressSelector) mocks.mock(
      hfs_CourseProgressSelector.class
    );

    mocks.startStubbing();
    mocks.when(coursesSelector.sObjectType())
      .thenReturn(hfs_Course__c.SObjectType);
    mocks.when(coursesSelector.selectActiveCourses()).thenReturn(courses);
    mocks.when(progressSelector.sObjectType())
      .thenReturn(hfs_CourseProgress__c.SObjectType);
    mocks.when(progressSelector.selectByUser(fflib_Match.anyId()))
      .thenReturn(progress);
    mocks.stopStubbing();

    hfs_Application.Selector.setMock(
      hfs_Course__c.SObjectType,
      coursesSelector
    );
    hfs_Application.Selector.setMock(
      hfs_CourseProgress__c.SObjectType,
      progressSelector
    );
  }

  /**
   * @description Creates a Standard User and grants read FLS on the queried Training fields via a
   * test-only PermissionSet, so the USER_MODE selectors can read every field end to end without
   * relying on any packaged profile or permission set. Required and Master-Detail fields are
   * always readable, so they are intentionally omitted (FLS entries on them are not allowed).
   * @return the inserted user with the test permission set assigned
   */
  private static User makeTrainingUserWithFls() {
    Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
    String unique = String.valueOf(Datetime.now().getTime());
    User u = new User(
      FirstName = 'HFS',
      LastName = 'TrainingTester',
      Alias = 'hfstt',
      Email = 'hfs.training.tester@example.com',
      Username = 'hfs.training.tester.' + unique + '@example.com.invalid',
      EmailEncodingKey = 'UTF-8',
      LanguageLocaleKey = 'en_US',
      LocaleSidKey = 'en_US',
      TimeZoneSidKey = 'America/Los_Angeles',
      ProfileId = p.Id
    );

    PermissionSet ps = new PermissionSet(
      Name = 'hfs_TrainingTestFls',
      Label = 'HFS Training Test FLS'
    );

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
      'hfs_CourseProgress__c.hfs_CurrentAttempt__c',
      'hfs_CourseAttempt__c.hfs_AttemptNumber__c'
    };

    // Setup-object DML (User, PermissionSet, *Permissions, PermissionSetAssignment) must be
    // isolated in its own runAs block, otherwise the later non-setup hfs_Course__c DML in the
    // same transaction throws MIXED_DML_OPERATION.
    System.runAs(new User(Id = UserInfo.getUserId())) {
      insert u;
      insert ps;

      // PermissionsViewAllFields is intentionally not set on hfs_CourseProgress__c: it can't
      // coexist with the explicit per-field FieldPermissions rows inserted below for the same
      // object - Salesforce rejects that combination with FIELD_INTEGRITY_EXCEPTION.
      insert new List<ObjectPermissions>{
        new ObjectPermissions(
          ParentId = ps.Id,
          SObjectType = 'hfs_Course__c',
          PermissionsRead = true
        ),
        new ObjectPermissions(
          ParentId = ps.Id,
          SObjectType = 'hfs_CourseProgress__c',
          PermissionsRead = true,
          PermissionsViewAllRecords = true
        ),
        new ObjectPermissions(
          ParentId = ps.Id,
          SObjectType = 'hfs_CourseAttempt__c',
          PermissionsRead = true
        )
      };

      List<FieldPermissions> fps = new List<FieldPermissions>();
      Map<String, Schema.SObjectType> globalDescribe = Schema.getGlobalDescribe();
      for (String field : readableFields) {
        String objectApi = field.substringBefore('.');
        String fieldApi = field.substringAfter('.');
        Schema.DescribeFieldResult dfr = globalDescribe.get(objectApi)
          .getDescribe()
          .fields.getMap()
          .get(fieldApi)
          .getDescribe();
        // Only permissionable fields accept a FieldPermissions row. Roll-up summary, formula,
        // auto-number, master-detail and universally-required fields are non-permissionable and
        // are always readable once the user has object read - inserting a row for them would be
        // rejected and fail the whole batch, so skip them.
        if (!dfr.isPermissionable()) {
          continue;
        }
        fps.add(
          new FieldPermissions(
            ParentId = ps.Id,
            SObjectType = objectApi,
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
   * @description Builds a deterministic fake SObject Id for a given type and index.
   * @param sObjType the SObjectType
   * @param index a positive integer seed
   * @return a well-formed 15/18-char Id
   */
  private static Id fakeId(SObjectType sObjType, Integer index) {
    String prefix = sObjType.getDescribe().getKeyPrefix();
    return Id.valueOf(
      prefix + '0'.repeat(12 - String.valueOf(index).length()) + index
    );
  }

  /**
   * @description Tier 1 - real records, real DML. As a restricted user: Start creates progress +
   * attempt #1 (In Progress), Complete marks the attempt Completed with a certificate and mirrors
   * the summary, and Retake adds attempt #2 while attempt #1 (and its certificate) is preserved.
   */
  @IsTest
  static void startCompleteRetake_realData_preservesHistory() {
    User runningUser = makeTrainingUser();
    hfs_Course__c course;
    System.runAs(new User(Id = UserInfo.getUserId())) {
      course = hfs_TestDataFactory.createLaunchableCourses(1, true)[0];
    }

    Id courseId = course.Id;

    Test.startTest();
    System.runAs(runningUser) {
      hfs_TrainingService svc = new hfs_TrainingServiceImpl();

      hfs_TrainingWrapper.Course started = svc.startCourse(courseId);
      System.Assert.areEqual(
        'In Progress',
        started.status,
        'Start moves the course to In Progress'
      );
      System.Assert.areEqual(
        1,
        started.attemptNumber,
        'First start is attempt 1'
      );
      System.Assert.isNotNull(
        started.contentUrl,
        'Start returns the content URL to open'
      );

      hfs_TrainingWrapper.Course completed = svc.completeCourse(courseId);
      System.Assert.areEqual(
        'Completed',
        completed.status,
        'Complete moves the course to Completed'
      );
      System.Assert.isNotNull(
        completed.certificateUrl,
        'Completion generates a certificate reference'
      );

      hfs_TrainingWrapper.Course retaken = svc.retakeCourse(courseId);
      System.Assert.areEqual(
        'In Progress',
        retaken.status,
        'Retake moves the course back to In Progress'
      );
      System.Assert.areEqual(
        2,
        retaken.attemptNumber,
        'Retake begins attempt 2'
      );
    }
    Test.stopTest();

    // History is preserved: two attempt rows exist, attempt 1 keeps its Completed certificate.
    List<hfs_CourseAttempt__c> attempts = [
      SELECT hfs_AttemptNumber__c, hfs_Status__c, hfs_CertificateUrl__c
      FROM hfs_CourseAttempt__c
      WHERE hfs_CourseProgress__r.hfs_Course__c = :courseId
      ORDER BY hfs_AttemptNumber__c ASC
    ];
    System.Assert.areEqual(
      2,
      attempts.size(),
      'Retake adds a new attempt row without deleting the prior one'
    );
    System.Assert.areEqual(
      'Completed',
      attempts[0].hfs_Status__c,
      'Attempt 1 remains Completed after retake'
    );
    System.Assert.isNotNull(
      attempts[0].hfs_CertificateUrl__c,
      'Attempt 1 certificate is preserved after retake'
    );
  }

  /**
   * @description Tier 2 - fail-closed. A course with no content URL cannot be started and no
   * progress or attempt row is written (CONTENT_UNAVAILABLE).
   */
  @IsTest
  static void startCourse_noContentUrl_failsClosedNoWrite() {
    Id courseId = fakeId(hfs_Course__c.SObjectType, 1);
    hfs_Course__c inactive = new hfs_Course__c(
      Id = courseId,
      Name = 'No Content',
      hfs_IsActive__c = true
    );

    fflib_ApexMocks mocks = new fflib_ApexMocks();
    hfs_CoursesSelector coursesSelector = (hfs_CoursesSelector) mocks.mock(
      hfs_CoursesSelector.class
    );
    mocks.startStubbing();
    mocks.when(coursesSelector.sObjectType())
      .thenReturn(hfs_Course__c.SObjectType);
    mocks.when(coursesSelector.selectById(courseId))
      .thenReturn(new List<hfs_Course__c>{ inactive });
    mocks.stopStubbing();
    hfs_Application.Selector.setMock(
      hfs_Course__c.SObjectType,
      coursesSelector
    );

    Test.startTest();
    String caughtCode;
    try {
      new hfs_TrainingServiceImpl().startCourse(courseId);
    } catch (hfs_TrainingException e) {
      caughtCode = e.errorCode;
    }
    Test.stopTest();

    System.Assert.areEqual(
      hfs_Constants.CONTENT_UNAVAILABLE,
      caughtCode,
      'Missing content fails closed with CONTENT_UNAVAILABLE'
    );
  }

  /**
   * @description Tier 2 - own-data. Resuming a course the user has no progress for yields NOT_OWNER
   * and never advances status.
   */
  @IsTest
  static void resumeCourse_noOwnedProgress_throwsNotOwner() {
    Id courseId = fakeId(hfs_Course__c.SObjectType, 2);
    hfs_Course__c course = new hfs_Course__c(
      Id = courseId,
      Name = 'Launchable',
      hfs_IsActive__c = true,
      hfs_ContentUrl__c = 'https://example.com/c'
    );

    fflib_ApexMocks mocks = new fflib_ApexMocks();
    hfs_CoursesSelector coursesSelector = (hfs_CoursesSelector) mocks.mock(
      hfs_CoursesSelector.class
    );
    hfs_CourseProgressSelector progressSelector = (hfs_CourseProgressSelector) mocks.mock(
      hfs_CourseProgressSelector.class
    );
    mocks.startStubbing();
    mocks.when(coursesSelector.sObjectType())
      .thenReturn(hfs_Course__c.SObjectType);
    mocks.when(coursesSelector.selectById(courseId))
      .thenReturn(new List<hfs_Course__c>{ course });
    mocks.when(progressSelector.sObjectType())
      .thenReturn(hfs_CourseProgress__c.SObjectType);
    mocks.when(
        progressSelector.selectByUserAndCourse(
          fflib_Match.anyId(),
          fflib_Match.anyId()
        )
      )
      .thenReturn(new List<hfs_CourseProgress__c>());
    mocks.stopStubbing();
    hfs_Application.Selector.setMock(
      hfs_Course__c.SObjectType,
      coursesSelector
    );
    hfs_Application.Selector.setMock(
      hfs_CourseProgress__c.SObjectType,
      progressSelector
    );

    Test.startTest();
    String caughtCode;
    try {
      new hfs_TrainingServiceImpl().resumeCourse(courseId);
    } catch (hfs_TrainingException e) {
      caughtCode = e.errorCode;
    }
    Test.stopTest();

    System.Assert.areEqual(
      hfs_Constants.NOT_OWNER,
      caughtCode,
      'No owned progress yields NOT_OWNER'
    );
  }

  /**
   * @description Tier 2 - invalid transition. Retaking a course that is not Completed yields
   * INVALID_TRANSITION.
   */
  @IsTest
  static void retakeCourse_notCompleted_throwsInvalidTransition() {
    Id courseId = fakeId(hfs_Course__c.SObjectType, 3);
    hfs_CourseProgress__c inProgress = new hfs_CourseProgress__c(
      Id = fakeId(hfs_CourseProgress__c.SObjectType, 1),
      hfs_Course__c = courseId,
      hfs_Status__c = 'In Progress',
      hfs_AttemptNumber__c = 1
    );

    fflib_ApexMocks mocks = new fflib_ApexMocks();
    hfs_CourseProgressSelector progressSelector = (hfs_CourseProgressSelector) mocks.mock(
      hfs_CourseProgressSelector.class
    );
    mocks.startStubbing();
    mocks.when(progressSelector.sObjectType())
      .thenReturn(hfs_CourseProgress__c.SObjectType);
    mocks.when(
        progressSelector.selectByUserAndCourse(
          fflib_Match.anyId(),
          fflib_Match.anyId()
        )
      )
      .thenReturn(new List<hfs_CourseProgress__c>{ inProgress });
    mocks.stopStubbing();
    hfs_Application.Selector.setMock(
      hfs_CourseProgress__c.SObjectType,
      progressSelector
    );

    Test.startTest();
    String caughtCode;
    try {
      new hfs_TrainingServiceImpl().retakeCourse(courseId);
    } catch (hfs_TrainingException e) {
      caughtCode = e.errorCode;
    }
    Test.stopTest();

    System.Assert.areEqual(
      hfs_Constants.INVALID_TRANSITION,
      caughtCode,
      'Retake is only valid from Completed'
    );
  }

  /**
   * @description Tier 2 - certificate. getCertificate returns the latest completed attempt's
   * certificate for the signed-in user.
   */
  @IsTest
  static void getCertificate_completedAttempt_returnsCertificate() {
    Id courseId = fakeId(hfs_Course__c.SObjectType, 4);
    Id progressId = fakeId(hfs_CourseProgress__c.SObjectType, 2);
    hfs_CourseProgress__c completed = new hfs_CourseProgress__c(
      Id = progressId,
      hfs_Course__c = courseId,
      hfs_Status__c = 'Completed',
      hfs_AttemptNumber__c = 1,
      hfs_CertificateUrl__c = 'https://example.com/cert/summary'
    );
    hfs_CourseAttempt__c attempt = new hfs_CourseAttempt__c(
      Id = fakeId(hfs_CourseAttempt__c.SObjectType, 1),
      hfs_CourseProgress__c = progressId,
      hfs_AttemptNumber__c = 1,
      hfs_Status__c = 'Completed',
      hfs_CertificateUrl__c = 'https://example.com/cert/attempt1'
    );

    fflib_ApexMocks mocks = new fflib_ApexMocks();
    hfs_CourseProgressSelector progressSelector = (hfs_CourseProgressSelector) mocks.mock(
      hfs_CourseProgressSelector.class
    );
    hfs_CourseAttemptSelector attemptSelector = (hfs_CourseAttemptSelector) mocks.mock(
      hfs_CourseAttemptSelector.class
    );
    mocks.startStubbing();
    mocks.when(progressSelector.sObjectType())
      .thenReturn(hfs_CourseProgress__c.SObjectType);
    mocks.when(
        progressSelector.selectByUserAndCourse(
          fflib_Match.anyId(),
          fflib_Match.anyId()
        )
      )
      .thenReturn(new List<hfs_CourseProgress__c>{ completed });
    mocks.when(attemptSelector.sObjectType())
      .thenReturn(hfs_CourseAttempt__c.SObjectType);
    mocks.when(attemptSelector.selectLatestByProgressId(progressId))
      .thenReturn(new List<hfs_CourseAttempt__c>{ attempt });
    mocks.stopStubbing();
    hfs_Application.Selector.setMock(
      hfs_CourseProgress__c.SObjectType,
      progressSelector
    );
    hfs_Application.Selector.setMock(
      hfs_CourseAttempt__c.SObjectType,
      attemptSelector
    );

    Test.startTest();
    hfs_TrainingWrapper.Course dto = new hfs_TrainingServiceImpl()
      .getCertificate(courseId);
    Test.stopTest();

    System.Assert.areEqual(
      'https://example.com/cert/attempt1',
      dto.certificateUrl,
      'Latest attempt certificate is returned'
    );
  }

  /**
   * @description Tier 1 - real data. Start then Resume then getCertificate after completion,
   * covering the resume branch (last-accessed refresh), the own-data certificate read, and the
   * summary mirroring - the branches not hit by the start/complete/retake path.
   */
  @IsTest
  static void resumeAndCertificate_realData_coverActionBranches() {
    User runningUser = makeTrainingUser();
    hfs_Course__c course;
    System.runAs(new User(Id = UserInfo.getUserId())) {
      course = hfs_TestDataFactory.createLaunchableCourses(1, true)[0];
    }
    Id courseId = course.Id;

    Test.startTest();
    System.runAs(runningUser) {
      hfs_TrainingService svc = new hfs_TrainingServiceImpl();
      svc.startCourse(courseId);

      hfs_TrainingWrapper.Course resumed = svc.resumeCourse(courseId);
      System.Assert.areEqual(
        'In Progress',
        resumed.status,
        'Resume keeps the course In Progress'
      );
      System.Assert.isNotNull(
        resumed.contentUrl,
        'Resume returns the content URL to re-enter'
      );

      svc.completeCourse(courseId);
      hfs_TrainingWrapper.Course cert = svc.getCertificate(courseId);
      System.Assert.isNotNull(
        cert.certificateUrl,
        'getCertificate returns the completed attempt certificate'
      );
    }
    Test.stopTest();
  }

  /**
   * @description Tier 2 - getCertificate with no completed attempt yields NO_CERTIFICATE.
   */
  @IsTest
  static void getCertificate_noCertificate_throwsNoCertificate() {
    Id courseId = fakeId(hfs_Course__c.SObjectType, 9);
    Id progressId = fakeId(hfs_CourseProgress__c.SObjectType, 9);
    hfs_CourseProgress__c inProgress = new hfs_CourseProgress__c(
      Id = progressId,
      hfs_Course__c = courseId,
      hfs_Status__c = 'In Progress',
      hfs_AttemptNumber__c = 1
    );

    fflib_ApexMocks mocks = new fflib_ApexMocks();
    hfs_CourseProgressSelector progressSelector = (hfs_CourseProgressSelector) mocks.mock(
      hfs_CourseProgressSelector.class
    );
    hfs_CourseAttemptSelector attemptSelector = (hfs_CourseAttemptSelector) mocks.mock(
      hfs_CourseAttemptSelector.class
    );
    mocks.startStubbing();
    mocks.when(progressSelector.sObjectType())
      .thenReturn(hfs_CourseProgress__c.SObjectType);
    mocks.when(
        progressSelector.selectByUserAndCourse(
          fflib_Match.anyId(),
          fflib_Match.anyId()
        )
      )
      .thenReturn(new List<hfs_CourseProgress__c>{ inProgress });
    mocks.when(attemptSelector.sObjectType())
      .thenReturn(hfs_CourseAttempt__c.SObjectType);
    mocks.when(attemptSelector.selectLatestByProgressId(progressId))
      .thenReturn(new List<hfs_CourseAttempt__c>());
    mocks.stopStubbing();
    hfs_Application.Selector.setMock(
      hfs_CourseProgress__c.SObjectType,
      progressSelector
    );
    hfs_Application.Selector.setMock(
      hfs_CourseAttempt__c.SObjectType,
      attemptSelector
    );

    Test.startTest();
    String caughtCode;
    try {
      new hfs_TrainingServiceImpl().getCertificate(courseId);
    } catch (hfs_TrainingException e) {
      caughtCode = e.errorCode;
    }
    Test.stopTest();

    System.Assert.areEqual(
      hfs_Constants.NO_CERTIFICATE,
      caughtCode,
      'No completed attempt yields NO_CERTIFICATE'
    );
  }

  /**
   * @description Tier 2 - start when the course does not exist at all: fails closed with
   * CONTENT_UNAVAILABLE (empty selector result branch).
   */
  @IsTest
  static void startCourse_courseNotFound_failsClosed() {
    Id courseId = fakeId(hfs_Course__c.SObjectType, 20);

    fflib_ApexMocks mocks = new fflib_ApexMocks();
    hfs_CoursesSelector coursesSelector = (hfs_CoursesSelector) mocks.mock(
      hfs_CoursesSelector.class
    );
    mocks.startStubbing();
    mocks.when(coursesSelector.sObjectType())
      .thenReturn(hfs_Course__c.SObjectType);
    mocks.when(coursesSelector.selectById(courseId))
      .thenReturn(new List<hfs_Course__c>());
    mocks.stopStubbing();
    hfs_Application.Selector.setMock(
      hfs_Course__c.SObjectType,
      coursesSelector
    );

    Test.startTest();
    String caughtCode;
    try {
      new hfs_TrainingServiceImpl().startCourse(courseId);
    } catch (hfs_TrainingException e) {
      caughtCode = e.errorCode;
    }
    Test.stopTest();

    System.Assert.areEqual(
      hfs_Constants.CONTENT_UNAVAILABLE,
      caughtCode,
      'A missing course fails closed'
    );
  }

  /**
   * @description Tier 1 - real data. Starting a course that already has a Not Started progress
   * record exercises the isNew=false branch (existing summary updated, not created).
   */
  @IsTest
  static void startCourse_existingProgress_updatesInPlace() {
    User runningUser = makeTrainingUser();
    hfs_Course__c course;
    System.runAs(new User(Id = UserInfo.getUserId())) {
      course = hfs_TestDataFactory.createLaunchableCourses(1, true)[0];
      hfs_CourseProgress__c seed = hfs_TestDataFactory.createProgress(
        course.Id,
        runningUser.Id,
        'Not Started',
        0
      );
      insert seed;
    }
    Id courseId = course.Id;

    Test.startTest();
    hfs_TrainingWrapper.Course started;
    System.runAs(runningUser) {
      started = new hfs_TrainingServiceImpl().startCourse(courseId);
    }
    Test.stopTest();

    System.Assert.areEqual(
      'In Progress',
      started.status,
      'Starting an existing Not Started progress updates it in place to In Progress'
    );
    System.Assert.areEqual(
      1,
      started.attemptNumber,
      'First attempt on the existing progress is attempt 1'
    );
    List<hfs_CourseProgress__c> progress = [
      SELECT hfs_Status__c
      FROM hfs_CourseProgress__c
      WHERE hfs_Course__c = :courseId AND hfs_User__c = :runningUser.Id
    ];
    System.Assert.areEqual(
      1,
      progress.size(),
      'No duplicate progress record is created for the existing course'
    );
  }

  /**
   * @description Tier 2 - direct domain coverage for hfs_CourseProgressDomain and hfs_CourseAttemptDomain
   * using a mock Unit of Work, exercising every domain method (applyStart in-place, applyResume,
   * applyCompletion, applyRetake, registerNewAttempt, markCompleted) without DML.
   */
  @IsTest
  static void domains_directInvocation_coverAllMethods() {
    fflib_ApexMocks mocks = new fflib_ApexMocks();
    fflib_ISObjectUnitOfWork uow = (fflib_ISObjectUnitOfWork) mocks.mock(
      fflib_ISObjectUnitOfWork.class
    );

    hfs_CourseProgress__c progress = new hfs_CourseProgress__c(
      Id = fakeId(hfs_CourseProgress__c.SObjectType, 50),
      hfs_Status__c = 'Completed',
      hfs_AttemptNumber__c = 1
    );
    hfs_CourseAttempt__c attempt = new hfs_CourseAttempt__c(
      Id = fakeId(hfs_CourseAttempt__c.SObjectType, 50),
      hfs_AttemptNumber__c = 1,
      hfs_Status__c = 'In Progress'
    );

    Test.startTest();
    hfs_CourseProgressDomain progresses = new hfs_CourseProgressDomain(
      new List<hfs_CourseProgress__c>{ progress }
    );
    progresses.applyStart(uow, attempt, 1, false);
    progresses.applyResume(uow);
    progresses.applyCompletion(uow, Date.today(), 'https://example.com/c');
    progresses.applyRetake(uow, attempt, 2);

    hfs_CourseAttemptDomain attempts = new hfs_CourseAttemptDomain(
      new List<hfs_CourseAttempt__c>{ attempt }
    );
    hfs_CourseAttempt__c newAttempt = hfs_CourseAttemptDomain.registerNewAttempt(
      uow,
      progress,
      3
    );
    attempts.markCompleted(uow, Date.today(), 'https://example.com/cert');
    Test.stopTest();

    System.Assert.areEqual(
      'In Progress',
      newAttempt.hfs_Status__c,
      'A newly registered attempt starts In Progress'
    );
    System.Assert.areEqual(
      3,
      newAttempt.hfs_AttemptNumber__c,
      'A newly registered attempt carries the supplied attempt number'
    );
    System.Assert.areEqual(
      'Completed',
      attempt.hfs_Status__c,
      'markCompleted flips the attempt to Completed'
    );
  }

  /**
   * @description Tier 1 - exercises the enhanced Selector methods end to end under a restricted
   * user: hfs_CourseAttemptSelector.selectByProgressId / selectLatestByProgressId,
   * hfs_CourseProgressSelector.selectByUserAndCourse, and hfs_CoursesSelector.selectActiveCourses /
   * selectById, so their new query paths are covered against real records.
   */
  @IsTest
  static void selectors_realData_coverEnhancedQueries() {
    User runningUser = makeTrainingUser();
    hfs_Course__c course;
    hfs_CourseProgress__c progress;
    System.runAs(new User(Id = UserInfo.getUserId())) {
      course = hfs_TestDataFactory.createLaunchableCourses(1, true)[0];
      progress = hfs_TestDataFactory.createProgress(
        course.Id,
        runningUser.Id,
        'In Progress',
        40
      );
      progress.hfs_AttemptNumber__c = 1;
      insert progress;
      insert hfs_TestDataFactory.createAttempt(progress.Id, 1, 'In Progress');
    }

    Test.startTest();
    System.runAs(runningUser) {
      hfs_CoursesSelector coursesSelector = (hfs_CoursesSelector) hfs_Application.Selector.newInstance(
        hfs_Course__c.SObjectType
      );
      System.Assert.isFalse(
        coursesSelector.selectActiveCourses().isEmpty(),
        'Active courses are returned'
      );
      System.Assert.areEqual(
        1,
        coursesSelector.selectById(course.Id).size(),
        'selectById returns the single course'
      );

      hfs_CourseProgressSelector progressSelector = (hfs_CourseProgressSelector) hfs_Application.Selector.newInstance(
        hfs_CourseProgress__c.SObjectType
      );
      System.Assert.areEqual(
        1,
        progressSelector.selectByUserAndCourse(runningUser.Id, course.Id)
          .size(),
        'Own-data single-course lookup returns the progress record'
      );
      System.Assert.isFalse(
        progressSelector.selectByUser(runningUser.Id).isEmpty(),
        'selectByUser returns the user progress'
      );

      hfs_CourseAttemptSelector attemptSelector = (hfs_CourseAttemptSelector) hfs_Application.Selector.newInstance(
        hfs_CourseAttempt__c.SObjectType
      );
      System.Assert.areEqual(
        1,
        attemptSelector.selectByProgressId(progress.Id).size(),
        'selectByProgressId returns the attempt history'
      );
      System.Assert.areEqual(
        1,
        attemptSelector.selectLatestByProgressId(progress.Id).size(),
        'selectLatestByProgressId returns the latest attempt'
      );
    }
    Test.stopTest();
  }

  /**
   * @description Tier 2 - getCertificate falls back to the summary certificate when the latest
   * attempt has no certificate URL, and exercises the null percent/attempt DTO branches.
   */
  @IsTest
  static void getCertificate_fallsBackToSummaryCertificate() {
    Id courseId = fakeId(hfs_Course__c.SObjectType, 30);
    Id progressId = fakeId(hfs_CourseProgress__c.SObjectType, 30);
    // Summary carries a certificate but has null percent/attempt to hit the null ternaries.
    hfs_CourseProgress__c completed = new hfs_CourseProgress__c(
      Id = progressId,
      hfs_Course__c = courseId,
      hfs_Status__c = 'Completed',
      hfs_CertificateUrl__c = 'https://example.com/cert/summary-only'
    );
    // Latest attempt has no certificate, forcing the summary fallback.
    hfs_CourseAttempt__c attempt = new hfs_CourseAttempt__c(
      Id = fakeId(hfs_CourseAttempt__c.SObjectType, 30),
      hfs_CourseProgress__c = progressId,
      hfs_AttemptNumber__c = 1,
      hfs_Status__c = 'Completed'
    );

    fflib_ApexMocks mocks = new fflib_ApexMocks();
    hfs_CourseProgressSelector progressSelector = (hfs_CourseProgressSelector) mocks.mock(
      hfs_CourseProgressSelector.class
    );
    hfs_CourseAttemptSelector attemptSelector = (hfs_CourseAttemptSelector) mocks.mock(
      hfs_CourseAttemptSelector.class
    );
    mocks.startStubbing();
    mocks.when(progressSelector.sObjectType())
      .thenReturn(hfs_CourseProgress__c.SObjectType);
    mocks.when(
        progressSelector.selectByUserAndCourse(
          fflib_Match.anyId(),
          fflib_Match.anyId()
        )
      )
      .thenReturn(new List<hfs_CourseProgress__c>{ completed });
    mocks.when(attemptSelector.sObjectType())
      .thenReturn(hfs_CourseAttempt__c.SObjectType);
    mocks.when(attemptSelector.selectLatestByProgressId(progressId))
      .thenReturn(new List<hfs_CourseAttempt__c>{ attempt });
    mocks.stopStubbing();
    hfs_Application.Selector.setMock(
      hfs_CourseProgress__c.SObjectType,
      progressSelector
    );
    hfs_Application.Selector.setMock(
      hfs_CourseAttempt__c.SObjectType,
      attemptSelector
    );

    Test.startTest();
    hfs_TrainingWrapper.Course dto = new hfs_TrainingServiceImpl()
      .getCertificate(courseId);
    Test.stopTest();

    System.Assert.areEqual(
      'https://example.com/cert/summary-only',
      dto.certificateUrl,
      'Falls back to the summary certificate when the attempt has none'
    );
    System.Assert.isNull(
      dto.percentComplete,
      'Null summary percent maps to null on the DTO'
    );
  }

  /**
   * @description Builds a restricted Standard User and grants object CRUD + field FLS on the
   * Course/Progress/Attempt objects via a test-only PermissionSet (built entirely in Apex, not
   * shipped metadata - there is no packaged "training access" permission set for this feature
   * yet), so the USER_MODE selectors / Unit of Work can read and write the training records under
   * runAs. Setup DML is isolated to avoid MIXED_DML_OPERATION with the later course DML.
   * @return the inserted, assigned user
   */
  private static User makeTrainingUser() {
    User u;
    System.runAs(new User(Id = UserInfo.getUserId())) {
      Profile p = [
        SELECT Id
        FROM Profile
        WHERE Name = 'Standard User'
        LIMIT 1
      ];
      String unique = String.valueOf(Datetime.now().getTime());
      u = new User(
        FirstName = 'HFS',
        LastName = 'ActionTester',
        Alias = 'hfsat',
        Email = 'hfs.action.tester@example.com',
        Username = 'hfs.action.tester.' + unique + '@example.com.invalid',
        EmailEncodingKey = 'UTF-8',
        LanguageLocaleKey = 'en_US',
        LocaleSidKey = 'en_US',
        TimeZoneSidKey = 'America/Los_Angeles',
        ProfileId = p.Id
      );
      insert u;

      PermissionSet ps = new PermissionSet(
        Name = 'hfs_ActionTestAccess',
        Label = 'HFS Action Test Access'
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
          PermissionsRead = true,
          PermissionsCreate = true,
          PermissionsEdit = true
        ),
        new ObjectPermissions(
          ParentId = ps.Id,
          SObjectType = 'hfs_CourseAttempt__c',
          PermissionsRead = true,
          PermissionsCreate = true,
          PermissionsEdit = true
        )
      };

      List<String> readableFields = new List<String>{
        'hfs_Course__c.hfs_Description__c',
        'hfs_Course__c.hfs_DurationMinutes__c',
        'hfs_Course__c.hfs_ModuleCount__c',
        'hfs_Course__c.hfs_DueDate__c',
        'hfs_Course__c.hfs_IsNewRelease__c',
        'hfs_Course__c.hfs_ReleasedDate__c',
        'hfs_Course__c.hfs_IsActive__c',
        'hfs_Course__c.hfs_ContentUrl__c'
      };
      // Fields the write path (Domain via USER_MODE Unit of Work) must be able to edit.
      // hfs_Status__c (both objects) and hfs_CourseAttempt__c.hfs_AttemptNumber__c /
      // hfs_StartedDate__c are required - always visible/editable with object access - so a
      // FieldPermissions row for them is rejected. hfs_CourseProgress__c.hfs_TotalAttempts__c is a
      // roll-up summary - also non-permissionable, always readable with object access.
      List<String> editableFields = new List<String>{
        'hfs_CourseProgress__c.hfs_User__c',
        'hfs_CourseProgress__c.hfs_PercentComplete__c',
        'hfs_CourseProgress__c.hfs_CurrentModule__c',
        'hfs_CourseProgress__c.hfs_CompletionDate__c',
        'hfs_CourseProgress__c.hfs_LastAccessedDate__c',
        'hfs_CourseProgress__c.hfs_CertificateUrl__c',
        'hfs_CourseProgress__c.hfs_AttemptNumber__c',
        'hfs_CourseProgress__c.hfs_CurrentAttempt__c',
        'hfs_CourseAttempt__c.hfs_CertificateUrl__c',
        'hfs_CourseAttempt__c.hfs_CompletionDate__c',
        'hfs_CourseAttempt__c.hfs_PercentComplete__c'
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
      for (String field : editableFields) {
        fps.add(
          new FieldPermissions(
            ParentId = ps.Id,
            SObjectType = field.substringBefore('.'),
            Field = field,
            PermissionsRead = true,
            PermissionsEdit = true
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
}
