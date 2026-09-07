/**
 * @description Selector for hfs_CourseAttempt__c built on fflib_SObjectSelector (HFS-34). Provides
 * own-data attempt-history queries scoped to a parent progress record; because hfs_CourseAttempt__c
 * is a Master-Detail child of hfs_CourseProgress__c, filtering to a progress the user owns keeps a
 * user's attempt history private to them. Runs in USER_MODE so CRUD/FLS are enforced at query time.
 */
public inherited sharing virtual class hfs_CourseAttemptSelector extends fflib_SObjectSelector {
  /**
   * @description Runs the selector in USER_MODE so CRUD/FLS are enforced on every query.
   */
  public hfs_CourseAttemptSelector() {
    super();
    setDataAccess(fflib_SObjectSelector.DataAccess.USER_MODE);
  }

  /**
   * @description The SObjectType this selector queries.
   * @return hfs_CourseAttempt__c SObjectType
   */
  public virtual Schema.SObjectType getSObjectType() {
    return hfs_CourseAttempt__c.SObjectType;
  }

  /**
   * @description The fields every query for this object returns.
   * @return the list of hfs_CourseAttempt__c fields
   */
  public virtual List<Schema.SObjectField> getSObjectFieldList() {
    return new List<Schema.SObjectField>{
      hfs_CourseAttempt__c.Id,
      hfs_CourseAttempt__c.hfs_CourseProgress__c,
      hfs_CourseAttempt__c.hfs_AttemptNumber__c,
      hfs_CourseAttempt__c.hfs_Status__c,
      hfs_CourseAttempt__c.hfs_StartedDate__c,
      hfs_CourseAttempt__c.hfs_CompletionDate__c,
      hfs_CourseAttempt__c.hfs_PercentComplete__c,
      hfs_CourseAttempt__c.hfs_CertificateUrl__c
    };
  }

  /**
   * @description Returns every attempt row for the supplied progress record, newest attempt first.
   * @param progressId the parent hfs_CourseProgress__c Id
   * @return the attempt records under that progress, ordered by attempt number descending
   */
  public virtual List<hfs_CourseAttempt__c> selectByProgressId(Id progressId) {
    String soql = newQueryFactory()
      .setEnforceFLS(fflib_QueryFactory.FLSEnforcement.NONE)
      .setCondition('hfs_CourseProgress__c = :progressId')
      .setOrdering(
        'hfs_AttemptNumber__c',
        fflib_QueryFactory.SortOrder.DESCENDING
      )
      .toSOQL();
    return (List<hfs_CourseAttempt__c>) Database.queryWithBinds(
      soql,
      new Map<String, Object>{ 'progressId' => progressId },
      AccessLevel.USER_MODE
    );
  }

  /**
   * @description Returns the single latest attempt for the supplied progress record, or an empty
   * list when there are none.
   * @param progressId the parent hfs_CourseProgress__c Id
   * @return the latest attempt (list of at most one)
   */
  public virtual List<hfs_CourseAttempt__c> selectLatestByProgressId(
    Id progressId
  ) {
    String soql = newQueryFactory()
      .setEnforceFLS(fflib_QueryFactory.FLSEnforcement.NONE)
      .setCondition('hfs_CourseProgress__c = :progressId')
      .setOrdering(
        'hfs_AttemptNumber__c',
        fflib_QueryFactory.SortOrder.DESCENDING
      )
      .setLimit(1)
      .toSOQL();
    return (List<hfs_CourseAttempt__c>) Database.queryWithBinds(
      soql,
      new Map<String, Object>{ 'progressId' => progressId },
      AccessLevel.USER_MODE
    );
  }
}
