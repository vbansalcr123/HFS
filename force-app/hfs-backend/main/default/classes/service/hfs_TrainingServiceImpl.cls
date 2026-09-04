/**
 * @description Implementation of the Training use case. Orchestrates the two Selectors, left-joins
 * active courses with the signed-in user's own progress, derives each card's status/percent/dates,
 * and computes the per-user progress summary. Read-only (writes belong to HFS-34). No SOQL/DML in
 * loops - the view is built from two bulk queries then merged in memory.
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
}
