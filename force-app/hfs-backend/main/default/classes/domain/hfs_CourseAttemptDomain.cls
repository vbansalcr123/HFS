/**
 * @description Domain class (plural) for hfs_CourseAttempt__c (HFS-34). Owns object-level behaviour
 * on a List of attempt records: builds a new attempt row on Start / Retake and marks an attempt
 * Completed with its own completion date / percent / certificate. Registers all changes with a
 * passed-in Unit of Work and never commits (the Service owns the transaction boundary). Attempts
 * are never deleted on retake - a new row is always added, so history is preserved by construction.
 */
public inherited sharing class hfs_CourseAttemptDomain extends fflib_SObjectDomain {
  /** Attempt status values. */
  public static final String STATUS_IN_PROGRESS = 'In Progress';
  public static final String STATUS_COMPLETED = 'Completed';

  /**
   * @description Constructs the domain over a list of attempt records.
   * @param records the attempt records this domain operates on
   */
  public hfs_CourseAttemptDomain(List<hfs_CourseAttempt__c> records) {
    super(records);
  }

  /**
   * @description Builds a brand-new In Progress attempt row for the given attempt number and
   * registers it new on the Unit of Work, linking it to its parent progress via a relationship so
   * the Master-Detail resolves once the parent is committed. Never commits.
   * @param uow the transaction's Unit of Work
   * @param parentProgress the owning progress record
   * @param attemptNumber the sequential attempt number (1 on first Start, +1 per Retake)
   * @return the new attempt record (already registered on the Unit of Work)
   */
  public static hfs_CourseAttempt__c registerNewAttempt(
    fflib_ISObjectUnitOfWork uow,
    hfs_CourseProgress__c parentProgress,
    Integer attemptNumber
  ) {
    hfs_CourseAttempt__c attempt = new hfs_CourseAttempt__c(
      hfs_AttemptNumber__c = attemptNumber,
      hfs_Status__c = STATUS_IN_PROGRESS,
      hfs_StartedDate__c = System.now(),
      hfs_PercentComplete__c = 0
    );
    uow.registerNew(
      attempt,
      hfs_CourseAttempt__c.hfs_CourseProgress__c,
      parentProgress
    );
    return attempt;
  }

  /**
   * @description Marks the (single) current attempt Completed with its own completion date,
   * percent 100 and certificate, and registers it dirty. Never commits.
   * @param uow the transaction's Unit of Work
   * @param completionDate the completion date for this attempt
   * @param certificateUrl the certificate issued for this attempt
   */
  public void markCompleted(
    fflib_ISObjectUnitOfWork uow,
    Date completionDate,
    String certificateUrl
  ) {
    for (hfs_CourseAttempt__c attempt : (List<hfs_CourseAttempt__c>) Records) {
      attempt.hfs_Status__c = STATUS_COMPLETED;
      attempt.hfs_CompletionDate__c = completionDate;
      attempt.hfs_PercentComplete__c = 100;
      attempt.hfs_CertificateUrl__c = certificateUrl;
      uow.registerDirty(attempt);
    }
  }

  /**
   * @description fflib Constructor hook so the Domain resolves through hfs_Application.Domain.
   */
  public class Constructor implements fflib_SObjectDomain.IConstructable {
    /**
     * @description Builds an hfs_CourseAttemptDomain domain from a record list.
     * @param records the attempt records
     * @return the domain instance
     */
    public fflib_SObjectDomain construct(List<SObject> records) {
      return new hfs_CourseAttemptDomain((List<hfs_CourseAttempt__c>) records);
    }
  }
}
