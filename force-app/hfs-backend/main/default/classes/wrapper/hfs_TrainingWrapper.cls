/**
 * @description Single combined wrapper carrying all data the Training page needs: the per-user
 * progress summary plus the flat list of course cards. Nested inner classes keep the payload
 * structured (view.summary and view.courses) while consolidating what used to be three separate
 * top-level wrapper classes. This is the payload inside hfs_Response.
 */
public class hfs_TrainingWrapper {
  /** The computed per-user learning progress summary. */
  @AuraEnabled
  public Summary summary { get; set; }

  /** The full list of course cards (unfiltered; the LWC filters by category in memory). */
  @AuraEnabled
  public List<Course> courses { get; set; }

  /**
   * @description Creates an empty view with an initialised course list.
   */
  public hfs_TrainingWrapper() {
    this.courses = new List<Course>();
  }

  /**
   * @description Per-user learning progress summary shown in the dark progress panel. All values
   * are computed in the Service for the signed-in user only.
   */
  public class Summary {
    /** Percent complete across all active courses (0-100). */
    @AuraEnabled
    public Integer percentComplete { get; set; }

    /** Number of courses the user has completed. */
    @AuraEnabled
    public Integer coursesCompleted { get; set; }

    /** Total number of active courses in the catalog. */
    @AuraEnabled
    public Integer coursesTotal { get; set; }

    /** Number of courses remaining (total minus completed). */
    @AuraEnabled
    public Integer coursesRemaining { get; set; }

    /** Estimated remaining time in minutes (sum of remaining course durations). */
    @AuraEnabled
    public Integer estRemainingMinutes { get; set; }

    /** Course Id to resume (most recently accessed In Progress course), if any. */
    @AuraEnabled
    public Id resumeCourseId { get; set; }

    /** True when the user has at least one progress record; false triggers the first-time state. */
    @AuraEnabled
    public Boolean hasProgress { get; set; }
  }

  /**
   * @description A single course card: the course catalog record combined with the signed-in
   * user's own progress into a flat, presentation-ready shape.
   */
  public class Course {
    /** Course record Id. */
    @AuraEnabled
    public Id id { get; set; }

    /** Course category (picklist value). */
    @AuraEnabled
    public String category { get; set; }

    /** Course title (Name). */
    @AuraEnabled
    public String title { get; set; }

    /** Short course description. */
    @AuraEnabled
    public String description { get; set; }

    /** Course length in minutes. */
    @AuraEnabled
    public Integer durationMinutes { get; set; }

    /** Number of modules in the course. */
    @AuraEnabled
    public Integer moduleCount { get; set; }

    /** Status for the current user: Completed, In Progress, or Not Started. */
    @AuraEnabled
    public String status { get; set; }

    /** Percent complete for the current user (0-100). */
    @AuraEnabled
    public Integer percentComplete { get; set; }

    /** Current module index for in-progress courses. */
    @AuraEnabled
    public Integer currentModule { get; set; }

    /** Completion date for completed courses. */
    @AuraEnabled
    public Date completionDate { get; set; }

    /** Due date, when the course carries one. */
    @AuraEnabled
    public Date dueDate { get; set; }

    /** True when a due date exists and is in the past for a not-yet-completed course. */
    @AuraEnabled
    public Boolean isOverdue { get; set; }

    /** True when the course is flagged as a new release. */
    @AuraEnabled
    public Boolean isNewRelease { get; set; }

    /** Release date shown on new-release courses. */
    @AuraEnabled
    public Date releasedDate { get; set; }

    /** Certificate URL for completed courses (read here; issuance is HFS-34). */
    @AuraEnabled
    public String certificateUrl { get; set; }
  }
}
