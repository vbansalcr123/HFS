/**
 * @description Tests for hfs_TrainingServiceImpl. Tier 1: a real end-to-end test with real DML and
 * 200+ records run as an FLS-limited user (USER_MODE selectors). Tier 2: fflib_ApexMocks-based
 * Selector variations that exercise summary/status derivation without DML.
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
      'hfs_CourseProgress__c.hfs_User__c',
      'hfs_CourseProgress__c.hfs_PercentComplete__c',
      'hfs_CourseProgress__c.hfs_CurrentModule__c',
      'hfs_CourseProgress__c.hfs_CompletionDate__c',
      'hfs_CourseProgress__c.hfs_CertificateUrl__c',
      'hfs_CourseProgress__c.hfs_LastAccessedDate__c'
    };

    // Setup-object DML (User, PermissionSet, *Permissions, PermissionSetAssignment) must be
    // isolated in its own runAs block, otherwise the later non-setup hfs_Course__c DML in the
    // same transaction throws MIXED_DML_OPERATION.
    System.runAs(new User(Id = UserInfo.getUserId())) {
      insert u;
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
}
