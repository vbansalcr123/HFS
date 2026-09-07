/**
 * @description Domain class (plural) for hfs_CourseProgress__c (HFS-34). Owns object-level
 * behaviour on a List of progress records: applies status transitions, sets current module /
 * percent on the current-state summary, points hfs_CurrentAttempt__c at the live attempt, and
 * keeps hfs_AttemptNumber__c in sync with the latest child. Registers all changes with a
 * passed-in Unit of Work and never commits (the Service owns the transaction boundary).
 */
public inherited sharing class hfs_CourseProgressDomain extends fflib_SObjectDomain {
  /** Status values, kept in one place to avoid magic strings. */
  public static final String STATUS_NOT_STARTED = 'Not Started';
  public static final String STATUS_IN_PROGRESS = 'In Progress';
  public static final String STATUS_COMPLETED = 'Completed';

  /**
   * @description Constructs the domain over a list of progress records.
   * @param records the progress records this domain operates on
   */
  public hfs_CourseProgressDomain(List<hfs_CourseProgress__c> records) {
    super(records);
  }

  /**
   * @description Marks the (single) progress record as In Progress on Start, setting module 1 /
   * derived percent / last-accessed and the current attempt reference, and registers it dirty (or
   * new) on the Unit of Work. Never commits.
   * @param uow the transaction's Unit of Work
   * @param currentAttempt the attempt row this progress now points at
   * @param attemptNumber the current attempt number
   * @param isNew whether the progress record is being created in this transaction
   */
  public void applyStart(
    fflib_ISObjectUnitOfWork uow,
    hfs_CourseAttempt__c currentAttempt,
    Integer attemptNumber,
    Boolean isNew
  ) {
    for (
      hfs_CourseProgress__c progress : (List<hfs_CourseProgress__c>) Records
    ) {
      progress.hfs_Status__c = STATUS_IN_PROGRESS;
      progress.hfs_CurrentModule__c = 1;
      progress.hfs_PercentComplete__c = 0;
      progress.hfs_LastAccessedDate__c = System.now();
      progress.hfs_AttemptNumber__c = attemptNumber;
      if (isNew) {
        uow.registerNew(progress);
      } else {
        uow.registerDirty(progress);
      }
      // Point the summary at its live attempt once both are registered (relationship order).
      uow.registerRelationship(
        progress,
        hfs_CourseProgress__c.hfs_CurrentAttempt__c,
        currentAttempt
      );
    }
  }

  /**
   * @description Refreshes last-accessed on Resume without advancing status, and registers dirty.
   * @param uow the transaction's Unit of Work
   */
  public void applyResume(fflib_ISObjectUnitOfWork uow) {
    for (
      hfs_CourseProgress__c progress : (List<hfs_CourseProgress__c>) Records
    ) {
      progress.hfs_LastAccessedDate__c = System.now();
      uow.registerDirty(progress);
    }
  }

  /**
   * @description Mirrors the completed attempt's values onto the current-state summary (status
   * Completed, completion date, percent 100, certificate) and registers dirty. Never commits.
   * @param uow the transaction's Unit of Work
   * @param completionDate the attempt's completion date
   * @param certificateUrl the certificate issued for this attempt
   */
  public void applyCompletion(
    fflib_ISObjectUnitOfWork uow,
    Date completionDate,
    String certificateUrl
  ) {
    for (
      hfs_CourseProgress__c progress : (List<hfs_CourseProgress__c>) Records
    ) {
      progress.hfs_Status__c = STATUS_COMPLETED;
      progress.hfs_PercentComplete__c = 100;
      progress.hfs_CompletionDate__c = completionDate;
      progress.hfs_CertificateUrl__c = certificateUrl;
      progress.hfs_LastAccessedDate__c = System.now();
      uow.registerDirty(progress);
    }
  }

  /**
   * @description Repoints the summary at a new attempt on Retake: status back to In Progress,
   * module 1, incremented attempt number, and registers dirty. Prior attempt rows are untouched.
   * @param uow the transaction's Unit of Work
   * @param newAttempt the new attempt row this progress now points at
   * @param attemptNumber the incremented attempt number
   */
  public void applyRetake(
    fflib_ISObjectUnitOfWork uow,
    hfs_CourseAttempt__c newAttempt,
    Integer attemptNumber
  ) {
    for (
      hfs_CourseProgress__c progress : (List<hfs_CourseProgress__c>) Records
    ) {
      progress.hfs_Status__c = STATUS_IN_PROGRESS;
      progress.hfs_CurrentModule__c = 1;
      progress.hfs_PercentComplete__c = 0;
      progress.hfs_LastAccessedDate__c = System.now();
      progress.hfs_AttemptNumber__c = attemptNumber;
      uow.registerDirty(progress);
      uow.registerRelationship(
        progress,
        hfs_CourseProgress__c.hfs_CurrentAttempt__c,
        newAttempt
      );
    }
  }

  /**
   * @description fflib Constructor hook so the Domain resolves through hfs_Application.Domain.
   */
  public class Constructor implements fflib_SObjectDomain.IConstructable {
    /**
     * @description Builds an hfs_CourseProgressDomain domain from a record list.
     * @param records the progress records
     * @return the domain instance
     */
    public fflib_SObjectDomain construct(List<SObject> records) {
      return new hfs_CourseProgressDomain(
        (List<hfs_CourseProgress__c>) records
      );
    }
  }
}
