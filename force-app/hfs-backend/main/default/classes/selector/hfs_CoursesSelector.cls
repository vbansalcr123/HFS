/**
 * @description Selector for hfs_Course__c built on fflib_SObjectSelector. Runs in USER_MODE so
 * CRUD/FLS are enforced at query time. HFS-34 adds hfs_ContentUrl__c and hfs_IsActive__c to the
 * field list (for the launch / active-course guard checks) and a single-course lookup.
 */
public inherited sharing virtual class hfs_CoursesSelector extends fflib_SObjectSelector {
  /**
   * @description Runs the selector in USER_MODE so CRUD/FLS are enforced on every query.
   */
  public hfs_CoursesSelector() {
    super();
    setDataAccess(fflib_SObjectSelector.DataAccess.USER_MODE);
  }

  /**
   * @description The SObjectType this selector queries.
   * @return hfs_Course__c SObjectType
   */
  public virtual Schema.SObjectType getSObjectType() {
    return hfs_Course__c.SObjectType;
  }

  /**
   * @description The fields every query for this object returns.
   * @return the list of hfs_Course__c fields
   */
  public virtual List<Schema.SObjectField> getSObjectFieldList() {
    return new List<Schema.SObjectField>{
      hfs_Course__c.Id,
      hfs_Course__c.Name,
      hfs_Course__c.hfs_Category__c,
      hfs_Course__c.hfs_Description__c,
      hfs_Course__c.hfs_DurationMinutes__c,
      hfs_Course__c.hfs_ModuleCount__c,
      hfs_Course__c.hfs_DueDate__c,
      hfs_Course__c.hfs_IsNewRelease__c,
      hfs_Course__c.hfs_ReleasedDate__c,
      hfs_Course__c.hfs_IsActive__c,
      hfs_Course__c.hfs_ContentUrl__c
    };
  }

  /**
   * @description Default sort order for course lists.
   * @return the order-by clause
   */
  public override String getOrderBy() {
    return 'hfs_Category__c, Name';
  }

  /**
   * @description Returns only the active courses in the catalog.
   * @return the active courses
   */
  public virtual List<hfs_Course__c> selectActiveCourses() {
    return (List<hfs_Course__c>) Database.query(
      newQueryFactory().setCondition('hfs_IsActive__c = true').toSOQL()
    );
  }

  /**
   * @description Returns the single course for the supplied Id (used by the action guard to read
   * hfs_IsActive__c / hfs_ContentUrl__c before Start / Resume), or an empty list when none exists.
   * @param courseId the course Id
   * @return the course (list of at most one)
   */
  public virtual List<hfs_Course__c> selectById(Id courseId) {
    String soql = newQueryFactory()
      .setEnforceFLS(fflib_QueryFactory.FLSEnforcement.NONE)
      .setCondition('Id = :courseId')
      .setLimit(1)
      .toSOQL();
    return (List<hfs_Course__c>) Database.queryWithBinds(
      soql,
      new Map<String, Object>{ 'courseId' => courseId },
      AccessLevel.USER_MODE
    );
  }
}
