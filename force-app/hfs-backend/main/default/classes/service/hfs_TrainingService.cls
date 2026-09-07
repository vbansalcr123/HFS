/**
 * @description Service interface for the Training use case. Every Service is an interface plus an
 * implementation. A Service method represents a use case, not a CRUD wrapper. Reads (buildTrainingView)
 * and the HFS-34 action use cases (Start / Resume / Complete / Retake / View Certificate) all live on
 * this single Training service; action methods return hfs_TrainingWrapper.Course payloads (the same
 * wrapper the view uses, never raw SObjects) and throw typed hfs_TrainingException on business failures.
 */
public interface hfs_TrainingService {
  /**
   * @description Builds the Training view (progress summary + course cards) for the given user.
   * @param userId the user whose training view should be assembled
   * @return the populated Training view wrapper
   */
  hfs_TrainingWrapper buildTrainingView(Id userId);

  /**
   * @description Starts a Not Started course for the signed-in user: creates the progress summary
   * if needed (status In Progress), creates attempt #1, sets module 1 / last-accessed, and returns
   * the content URL to open. Fails closed with CONTENT_UNAVAILABLE when content is missing.
   * @param courseId the course to start
   * @return the resulting action payload
   */
  hfs_TrainingWrapper.Course startCourse(Id courseId);

  /**
   * @description Resumes an In Progress course: refreshes last-accessed, leaves status unchanged,
   * and returns the current module and content URL. Fails closed when content is unavailable.
   * @param courseId the course to resume
   * @return the resulting action payload
   */
  hfs_TrainingWrapper.Course resumeCourse(Id courseId);

  /**
   * @description Completes the current attempt: marks it Completed with completion date, percent
   * 100 and a generated certificate, and mirrors the latest values onto the summary.
   * @param courseId the course to complete
   * @return the resulting action payload
   */
  hfs_TrainingWrapper.Course completeCourse(Id courseId);

  /**
   * @description Retakes a Completed course: creates a NEW attempt row (attempt + 1, In Progress)
   * while leaving prior attempts / certificates untouched, and repoints the summary.
   * @param courseId the course to retake
   * @return the resulting action payload
   */
  hfs_TrainingWrapper.Course retakeCourse(Id courseId);

  /**
   * @description Returns the certificate URL for the signed-in user's latest completed attempt of
   * a course. Read-only. Fails with NO_CERTIFICATE when the user has no completed attempt.
   * @param courseId the course whose certificate is required
   * @return the resulting action payload carrying the certificate URL
   */
  hfs_TrainingWrapper.Course getCertificate(Id courseId);
}
