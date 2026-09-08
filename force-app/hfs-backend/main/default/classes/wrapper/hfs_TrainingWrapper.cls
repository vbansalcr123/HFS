/**
 * @description Single combined wrapper carrying all data the Training page needs: the per-user
 * progress summary plus the flat list of course cards, and the payload each Training action (HFS-34)
 * returns. Nested inner classes keep the payload structured (view.summary and view.courses) while
 * consolidating what used to be three separate top-level wrapper classes. Course also carries the
 * action-result fields (attemptNumber, contentUrl) so every Training controller response uses this
 * one wrapper rather than a separate action DTO. This is the payload inside hfs_Response.
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

  public class Summary {
    @AuraEnabled
    public Integer percentComplete { get; set; }
    @AuraEnabled
    public Integer coursesCompleted { get; set; }
    @AuraEnabled
    public Integer coursesTotal { get; set; }
    @AuraEnabled
    public Integer coursesRemaining { get; set; }
    @AuraEnabled
    public Integer estRemainingMinutes { get; set; }
    @AuraEnabled
    public Id resumeCourseId { get; set; }
    @AuraEnabled
    public Boolean hasProgress { get; set; }
  }

  public class Course {
    @AuraEnabled
    public Id id { get; set; }
    @AuraEnabled
    public String category { get; set; }
    @AuraEnabled
    public String title { get; set; }
    @AuraEnabled
    public String description { get; set; }
    @AuraEnabled
    public Integer durationMinutes { get; set; }
    @AuraEnabled
    public Integer moduleCount { get; set; }
    @AuraEnabled
    public String status { get; set; }
    @AuraEnabled
    public Integer percentComplete { get; set; }
    @AuraEnabled
    public Integer currentModule { get; set; }
    @AuraEnabled
    public Date completionDate { get; set; }
    @AuraEnabled
    public Date dueDate { get; set; }
    @AuraEnabled
    public Boolean isOverdue { get; set; }
    @AuraEnabled
    public Boolean isNewRelease { get; set; }
    @AuraEnabled
    public Date releasedDate { get; set; }
    @AuraEnabled
    public String certificateUrl { get; set; }

    // Action-result fields (HFS-34): populated by the Training action methods so the action payload
    // reuses this wrapper instead of a separate DTO. Null on the read/view path.

    /** The current attempt number after a Start / Complete / Retake action. */
    @AuraEnabled
    public Integer attemptNumber { get; set; }

    /** The content URL the container should open (Start / Resume / Retake). */
    @AuraEnabled
    public String contentUrl { get; set; }
  }
}
