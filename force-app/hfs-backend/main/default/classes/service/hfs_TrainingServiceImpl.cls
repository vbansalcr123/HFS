/**
 * @description Implementation of the Training use case. buildTrainingView orchestrates the two
 * Selectors, left-joins active courses with the signed-in user's own progress, derives each card's
 * status/percent/dates, and computes the per-user progress summary (read-only). The HFS-34 action
 * methods (Start / Resume / Complete / Retake / View Certificate) each own their transaction
 * boundary (one commitWork() per action), enforce own-data + fail-closed rules, and delegate
 * progress / attempt mutations to the Domain classes. Reads and writes both run in USER_MODE via the
 * Selectors / Unit of Work. No SOQL / DML in loops - views are built from bulk queries merged in
 * memory and the Domains operate on Lists batched by the Unit of Work.
 */
public inherited sharing class hfs_TrainingServiceImpl implements hfs_TrainingService {
  private static final String STATUS_COMPLETED = 'Completed';
  private static final String STATUS_IN_PROGRESS = 'In Progress';
  private static final String STATUS_NOT_STARTED = 'Not Started';

  /**
   * @description Builds the Training view (progress summary + course cards) for the given user.
   * @param userId the user whose training view should be assembled
   * @return the populated Training view wrapper
   */
  public hfs_TrainingWrapper buildTrainingView(Id userId) {
    hfs_CoursesSelector coursesSelector = (hfs_CoursesSelector) hfs_Application.Selector.newInstance(
      hfs_Course__c.SObjectType
    );
    hfs_CourseProgressSelector progressSelector = (hfs_CourseProgressSelector) hfs_Application.Selector.newInstance(
      hfs_CourseProgress__c.SObjectType
    );

    // Active courses only; retired courses drop out on next load.
    List<hfs_Course__c> courses = coursesSelector.selectActiveCourses();

    // Progress records pinned to the signed-in user only (own-data enforcement).
    List<hfs_CourseProgress__c> progressRecords = progressSelector.selectByUser(
      userId
    );

    Map<Id, hfs_CourseProgress__c> progressByCourseId = new Map<Id, hfs_CourseProgress__c>();
    for (hfs_CourseProgress__c progress : progressRecords) {
      progressByCourseId.put(progress.hfs_Course__c, progress);
    }

    hfs_TrainingWrapper view = new hfs_TrainingWrapper();
    Integer completedCount = 0;
    Integer remainingMinutes = 0;
    Id resumeCourseId = null;
    Datetime latestAccessed = null;

    for (hfs_Course__c course : courses) {
      hfs_CourseProgress__c progress = progressByCourseId.get(course.Id);
      hfs_TrainingWrapper.Course card = buildCard(course, progress);
      view.courses.add(card);

      if (STATUS_COMPLETED.equals(card.status)) {
        completedCount++;
      } else {
        // Not Started + In Progress durations feed the estimated remaining time.
        remainingMinutes += (course.hfs_DurationMinutes__c == null)
          ? 0
          : Integer.valueOf(course.hfs_DurationMinutes__c);
      }

      // Resume target = the In Progress course most recently accessed.
      if (
        STATUS_IN_PROGRESS.equals(card.status) &&
        progress != null &&
        progress.hfs_LastAccessedDate__c != null &&
        (latestAccessed == null ||
        progress.hfs_LastAccessedDate__c > latestAccessed)
      ) {
        latestAccessed = progress.hfs_LastAccessedDate__c;
        resumeCourseId = course.Id;
      }
    }

    view.summary = buildSummary(
      courses.size(),
      completedCount,
      remainingMinutes,
      resumeCourseId,
      !progressRecords.isEmpty()
    );
    return view;
  }

  /**
   * @description Builds a presentation-ready course card from a course and optional progress.
   * @param course the course catalog record
   * @param progress the current user's progress for this course (may be null)
   * @return the populated course card wrapper
   */
  private hfs_TrainingWrapper.Course buildCard(
    hfs_Course__c course,
    hfs_CourseProgress__c progress
  ) {
    hfs_TrainingWrapper.Course card = new hfs_TrainingWrapper.Course();
    card.id = course.Id;
    card.category = course.hfs_Category__c;
    card.title = course.Name;
    card.description = course.hfs_Description__c;
    card.durationMinutes = (course.hfs_DurationMinutes__c == null)
      ? null
      : Integer.valueOf(course.hfs_DurationMinutes__c);
    card.moduleCount = (course.hfs_ModuleCount__c == null)
      ? null
      : Integer.valueOf(course.hfs_ModuleCount__c);
    card.dueDate = course.hfs_DueDate__c;
    card.isNewRelease = course.hfs_IsNewRelease__c == true;
    card.releasedDate = course.hfs_ReleasedDate__c;

    if (progress == null) {
      card.status = STATUS_NOT_STARTED;
      card.percentComplete = 0;
    } else {
      card.status = String.isBlank(progress.hfs_Status__c)
        ? STATUS_NOT_STARTED
        : progress.hfs_Status__c;
      card.percentComplete = (progress.hfs_PercentComplete__c == null)
        ? 0
        : Integer.valueOf(progress.hfs_PercentComplete__c);
      card.currentModule = (progress.hfs_CurrentModule__c == null)
        ? null
        : Integer.valueOf(progress.hfs_CurrentModule__c);
      card.completionDate = progress.hfs_CompletionDate__c;
      card.certificateUrl = progress.hfs_CertificateUrl__c;
    }

    // Overdue when a due date is in the past and the course is not completed.
    card.isOverdue =
      card.dueDate != null &&
      card.dueDate < Date.today() &&
      !STATUS_COMPLETED.equals(card.status);
    return card;
  }

  /**
   * @description Builds the per-user progress summary, guarding divide-by-zero and returning an
   * explicit zero/first-time state when the user has no progress.
   * @param totalCourses total number of active courses
   * @param completedCount number of completed courses for the user
   * @param remainingMinutes summed duration of the user's remaining courses
   * @param resumeCourseId the resume-target course Id (may be null)
   * @param hasProgress whether the user has any progress records
   * @return the populated summary wrapper
   */
  private hfs_TrainingWrapper.Summary buildSummary(
    Integer totalCourses,
    Integer completedCount,
    Integer remainingMinutes,
    Id resumeCourseId,
    Boolean hasProgress
  ) {
    hfs_TrainingWrapper.Summary summary = new hfs_TrainingWrapper.Summary();
    summary.coursesTotal = totalCourses;
    summary.coursesCompleted = completedCount;
    summary.coursesRemaining = totalCourses - completedCount;
    summary.estRemainingMinutes = remainingMinutes;
    summary.resumeCourseId = resumeCourseId;
    summary.hasProgress = hasProgress;
    summary.percentComplete = (totalCourses == 0)
      ? 0
      : Integer.valueOf(
          Math.round((Decimal.valueOf(completedCount) / totalCourses) * 100)
        );
    return summary;
  }

  /**
   * @description Starts a Not Started course. Fails closed with CONTENT_UNAVAILABLE (no write) when
   * the course is inactive or has no content URL.
   * @param courseId the course to start
   * @return the resulting action payload
   */
  public hfs_TrainingWrapper.Course startCourse(Id courseId) {
    hfs_Course__c course = resolveLaunchableCourse(courseId);

    hfs_CourseProgressSelector progressSelector = progressSelector();
    List<hfs_CourseProgress__c> existing = progressSelector.selectByUserAndCourse(
      UserInfo.getUserId(),
      courseId
    );

    fflib_ISObjectUnitOfWork uow = hfs_Application.UnitOfWork.newInstance();

    hfs_CourseProgress__c progress;
    Boolean isNew = existing.isEmpty();
    if (isNew) {
      progress = new hfs_CourseProgress__c(
        hfs_User__c = UserInfo.getUserId(),
        hfs_Course__c = courseId
      );
    } else {
      progress = existing[0];
    }

    hfs_CourseAttempt__c attempt = hfs_CourseAttemptDomain.registerNewAttempt(
      uow,
      progress,
      1
    );
    ((hfs_CourseProgressDomain) hfs_Application.Domain.newInstance(
        new List<hfs_CourseProgress__c>{ progress }
      ))
      .applyStart(uow, attempt, 1, isNew);

    uow.commitWork();

    return buildDto(
      courseId,
      STATUS_IN_PROGRESS,
      0,
      1,
      null,
      1,
      course.hfs_ContentUrl__c,
      null
    );
  }

  /**
   * @description Resumes an In Progress course. Fails closed when content is unavailable.
   * @param courseId the course to resume
   * @return the resulting action payload
   */
  public hfs_TrainingWrapper.Course resumeCourse(Id courseId) {
    hfs_Course__c course = resolveLaunchableCourse(courseId);
    hfs_CourseProgress__c progress = resolveOwnedProgress(courseId);

    fflib_ISObjectUnitOfWork uow = hfs_Application.UnitOfWork.newInstance();
    ((hfs_CourseProgressDomain) hfs_Application.Domain.newInstance(
        new List<hfs_CourseProgress__c>{ progress }
      ))
      .applyResume(uow);
    uow.commitWork();

    Integer currentModule = (progress.hfs_CurrentModule__c == null)
      ? 1
      : Integer.valueOf(progress.hfs_CurrentModule__c);
    Integer percent = (progress.hfs_PercentComplete__c == null)
      ? 0
      : Integer.valueOf(progress.hfs_PercentComplete__c);
    return buildDto(
      courseId,
      STATUS_IN_PROGRESS,
      percent,
      currentModule,
      null,
      (progress.hfs_AttemptNumber__c == null)
        ? 1
        : Integer.valueOf(progress.hfs_AttemptNumber__c),
      course.hfs_ContentUrl__c,
      null
    );
  }

  /**
   * @description Completes the current attempt and mirrors the latest values onto the summary. The
   * completion is committed independently of any summary read, so if the summary source is briefly
   * unavailable the completion still persists and reconciles on next load.
   * @param courseId the course to complete
   * @return the resulting action payload
   */
  public hfs_TrainingWrapper.Course completeCourse(Id courseId) {
    hfs_CourseProgress__c progress = resolveOwnedProgress(courseId);

    hfs_CourseAttempt__c currentAttempt = resolveCurrentAttempt(progress);
    Date completionDate = Date.today();
    String certificateUrl = buildCertificateReference(progress.Id, courseId);

    fflib_ISObjectUnitOfWork uow = hfs_Application.UnitOfWork.newInstance();
    ((hfs_CourseAttemptDomain) hfs_Application.Domain.newInstance(
        new List<hfs_CourseAttempt__c>{ currentAttempt }
      ))
      .markCompleted(uow, completionDate, certificateUrl);
    ((hfs_CourseProgressDomain) hfs_Application.Domain.newInstance(
        new List<hfs_CourseProgress__c>{ progress }
      ))
      .applyCompletion(uow, completionDate, certificateUrl);
    uow.commitWork();

    return buildDto(
      courseId,
      STATUS_COMPLETED,
      100,
      progress.hfs_CurrentModule__c == null
        ? null
        : Integer.valueOf(progress.hfs_CurrentModule__c),
      completionDate,
      (progress.hfs_AttemptNumber__c == null)
        ? 1
        : Integer.valueOf(progress.hfs_AttemptNumber__c),
      null,
      certificateUrl
    );
  }

  /**
   * @description Retakes a Completed course: creates a NEW attempt row (attempt + 1) and repoints
   * the summary; prior attempt rows / certificates are never overwritten or deleted. Only valid
   * from Completed - otherwise INVALID_TRANSITION.
   * @param courseId the course to retake
   * @return the resulting action payload
   */
  public hfs_TrainingWrapper.Course retakeCourse(Id courseId) {
    hfs_CourseProgress__c progress = resolveOwnedProgress(courseId);

    if (!STATUS_COMPLETED.equals(progress.hfs_Status__c)) {
      throw new hfs_TrainingException(
        hfs_Constants.INVALID_TRANSITION,
        System.Label.hfs_Error_Training_Invalid_Transition
      );
    }

    Integer nextAttempt = (progress.hfs_AttemptNumber__c == null)
      ? 2
      : Integer.valueOf(progress.hfs_AttemptNumber__c) + 1;

    fflib_ISObjectUnitOfWork uow = hfs_Application.UnitOfWork.newInstance();
    hfs_CourseAttempt__c newAttempt = hfs_CourseAttemptDomain.registerNewAttempt(
      uow,
      progress,
      nextAttempt
    );
    ((hfs_CourseProgressDomain) hfs_Application.Domain.newInstance(
        new List<hfs_CourseProgress__c>{ progress }
      ))
      .applyRetake(uow, newAttempt, nextAttempt);
    uow.commitWork();

    return buildDto(
      courseId,
      STATUS_IN_PROGRESS,
      0,
      1,
      null,
      nextAttempt,
      null,
      null
    );
  }

  /**
   * @description Returns the certificate URL for the signed-in user's latest completed attempt.
   * @param courseId the course whose certificate is required
   * @return the resulting action payload carrying the certificate URL
   */
  public hfs_TrainingWrapper.Course getCertificate(Id courseId) {
    hfs_CourseProgress__c progress = resolveOwnedProgress(courseId);

    hfs_CourseAttemptSelector attemptSelector = (hfs_CourseAttemptSelector) hfs_Application.Selector.newInstance(
      hfs_CourseAttempt__c.SObjectType
    );
    List<hfs_CourseAttempt__c> latest = attemptSelector.selectLatestByProgressId(
      progress.Id
    );

    String certificateUrl = (!latest.isEmpty() &&
      String.isNotBlank(latest[0].hfs_CertificateUrl__c))
      ? latest[0].hfs_CertificateUrl__c
      : progress.hfs_CertificateUrl__c;

    if (String.isBlank(certificateUrl)) {
      throw new hfs_TrainingException(
        hfs_Constants.NO_CERTIFICATE,
        System.Label.hfs_Error_Training_No_Certificate
      );
    }

    return buildDto(
      courseId,
      progress.hfs_Status__c,
      (progress.hfs_PercentComplete__c == null)
        ? null
        : Integer.valueOf(progress.hfs_PercentComplete__c),
      null,
      progress.hfs_CompletionDate__c,
      (progress.hfs_AttemptNumber__c == null)
        ? null
        : Integer.valueOf(progress.hfs_AttemptNumber__c),
      null,
      certificateUrl
    );
  }

  /**
   * @description Reads the course and enforces the launch guard: the course must exist, be active
   * and carry a content URL, else fail closed with CONTENT_UNAVAILABLE (no record is written).
   * @param courseId the course to validate
   * @return the launchable course record
   */
  private hfs_Course__c resolveLaunchableCourse(Id courseId) {
    hfs_CoursesSelector coursesSelector = (hfs_CoursesSelector) hfs_Application.Selector.newInstance(
      hfs_Course__c.SObjectType
    );
    List<hfs_Course__c> courses = coursesSelector.selectById(courseId);
    if (
      courses.isEmpty() ||
      courses[0].hfs_IsActive__c != true ||
      String.isBlank(courses[0].hfs_ContentUrl__c)
    ) {
      throw new hfs_TrainingException(
        hfs_Constants.CONTENT_UNAVAILABLE,
        System.Label.hfs_Error_Training_Content_Unavailable
      );
    }
    return courses[0];
  }

  /**
   * @description Resolves the signed-in user's own progress for the course; own-data enforcement.
   * @param courseId the course whose progress is required
   * @return the owned progress record
   */
  private hfs_CourseProgress__c resolveOwnedProgress(Id courseId) {
    List<hfs_CourseProgress__c> existing = progressSelector()
      .selectByUserAndCourse(UserInfo.getUserId(), courseId);
    if (existing.isEmpty()) {
      throw new hfs_TrainingException(
        hfs_Constants.NOT_OWNER,
        System.Label.hfs_Error_Training_Not_Owner
      );
    }
    return existing[0];
  }

  /**
   * @description Resolves the live attempt for a progress record, throwing INVALID_TRANSITION when
   * there is no attempt to complete.
   * @param progress the owned progress record
   * @return the current attempt record
   */
  private hfs_CourseAttempt__c resolveCurrentAttempt(
    hfs_CourseProgress__c progress
  ) {
    hfs_CourseAttemptSelector attemptSelector = (hfs_CourseAttemptSelector) hfs_Application.Selector.newInstance(
      hfs_CourseAttempt__c.SObjectType
    );
    List<hfs_CourseAttempt__c> latest = attemptSelector.selectLatestByProgressId(
      progress.Id
    );
    if (latest.isEmpty()) {
      throw new hfs_TrainingException(
        hfs_Constants.INVALID_TRANSITION,
        System.Label.hfs_Error_Training_Invalid_Transition
      );
    }
    return latest[0];
  }

  /**
   * @description Builds the Salesforce-generated certificate reference for a completed attempt.
   * Points at the internal certificate Visualforce page keyed to the progress + course. If a
   * confirmed external LMS later owns certificates, this is the single swap point.
   * @param progressId the progress record Id
   * @param courseId the course Id
   * @return a relative certificate URL
   */
  private String buildCertificateReference(Id progressId, Id courseId) {
    return '/apex/hfs_TrainingCertificate?progressId=' +
      progressId +
      '&courseId=' +
      courseId;
  }

  /**
   * @description Resolves the progress selector through the Application factory.
   * @return the progress selector
   */
  private hfs_CourseProgressSelector progressSelector() {
    return (hfs_CourseProgressSelector) hfs_Application.Selector.newInstance(
      hfs_CourseProgress__c.SObjectType
    );
  }

  /**
   * @description Builds the action DTO returned to the Controller.
   * @param courseId the course acted on
   * @param status the resulting status
   * @param percent the resulting percent complete
   * @param currentModule the resulting current module
   * @param completionDate the completion date, if any
   * @param attemptNumber the current attempt number
   * @param contentUrl the content URL to open, if any
   * @param certificateUrl the certificate URL to open, if any
   * @return the populated DTO
   */
  private hfs_TrainingWrapper.Course buildDto(
    Id courseId,
    String status,
    Integer percent,
    Integer currentModule,
    Date completionDate,
    Integer attemptNumber,
    String contentUrl,
    String certificateUrl
  ) {
    hfs_TrainingWrapper.Course dto = new hfs_TrainingWrapper.Course();
    dto.id = courseId;
    dto.status = status;
    dto.percentComplete = percent;
    dto.currentModule = currentModule;
    dto.completionDate = completionDate;
    dto.attemptNumber = attemptNumber;
    dto.contentUrl = contentUrl;
    dto.certificateUrl = certificateUrl;
    return dto;
  }
}
