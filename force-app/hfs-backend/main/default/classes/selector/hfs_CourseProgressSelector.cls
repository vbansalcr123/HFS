/**
 * @description Selector for hfs_CourseProgress__c built on fflib_SObjectSelector. The typed
 * selectByUser / selectByUserAndCourse methods pin hfs_User__c to the supplied user, so a user's
 * payload can only ever contain their own progress. Runs in USER_MODE so CRUD/FLS are enforced at
 * query time. HFS-34 adds the summary/attempt fields and the single-course own-data lookup used by
 * the write actions.
 */
public inherited sharing virtual class hfs_CourseProgressSelector extends fflib_SObjectSelector {
  /**
   * @description Runs the selector in USER_MODE so CRUD/FLS are enforced on every query.
   */
  public hfs_CourseProgressSelector() {
    super();
    setDataAccess(fflib_SObjectSelector.DataAccess.USER_MODE);
  }

  /**
   * @description The SObjectType this selector queries.
   * @return hfs_CourseProgress__c SObjectType
   */
  public virtual Schema.SObjectType getSObjectType() {
    return hfs_CourseProgress__c.SObjectType;
  }

  /**
   * @description The fields every query for this object returns.
   * @return the list of hfs_CourseProgress__c fields
   */
  public virtual List<Schema.SObjectField> getSObjectFieldList() {
    return new List<Schema.SObjectField>{
      hfs_CourseProgress__c.Id,
      hfs_CourseProgress__c.hfs_Course__c,
      hfs_CourseProgress__c.hfs_Status__c,
      hfs_CourseProgress__c.hfs_PercentComplete__c,
      hfs_CourseProgress__c.hfs_CurrentModule__c,
      hfs_CourseProgress__c.hfs_CompletionDate__c,
      hfs_CourseProgress__c.hfs_CertificateUrl__c,
      hfs_CourseProgress__c.hfs_LastAccessedDate__c,
      hfs_CourseProgress__c.hfs_AttemptNumber__c,
      hfs_CourseProgress__c.hfs_CurrentAttempt__c,
      hfs_CourseProgress__c.hfs_TotalAttempts__c
    };
  }

  /**
   * @description Returns the progress records owned by the supplied user (own-data enforcement).
   * @param userId the user whose progress records are required
   * @return the user's course-progress records
   */
  public virtual List<hfs_CourseProgress__c> selectByUser(Id userId) {
    // The bind-based query enforces FLS/CRUD via AccessLevel.USER_MODE below, so the query
    // factory must NOT also inject WITH USER_MODE (double enforcement is a runtime error).
    String soql = newQueryFactory()
      .setEnforceFLS(fflib_QueryFactory.FLSEnforcement.NONE)
      .setCondition('hfs_User__c = :userId')
      .toSOQL();
    return (List<hfs_CourseProgress__c>) Database.queryWithBinds(
      soql,
      new Map<String, Object>{ 'userId' => userId },
      AccessLevel.USER_MODE
    );
  }

  /**
   * @description Returns the single progress record the supplied user owns for a single course
   * (own-data enforcement for the write actions), or an empty list when none exists.
   * @param userId the signed-in user
   * @param courseId the course whose progress is required
   * @return the user's progress for that course (list of at most one)
   */
  public virtual List<hfs_CourseProgress__c> selectByUserAndCourse(
    Id userId,
    Id courseId
  ) {
    String soql = newQueryFactory()
      .setEnforceFLS(fflib_QueryFactory.FLSEnforcement.NONE)
      .setCondition('hfs_User__c = :userId AND hfs_Course__c = :courseId')
      .setLimit(1)
      .toSOQL();
    return (List<hfs_CourseProgress__c>) Database.queryWithBinds(
      soql,
      new Map<String, Object>{ 'userId' => userId, 'courseId' => courseId },
      AccessLevel.USER_MODE
    );
  }
}
