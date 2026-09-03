/**
 * @description Selector for hfs_Course__c built on fflib_SObjectSelector. Centralises the field
 * list and the active-courses query. Runs in USER_MODE so CRUD/FLS are enforced at query time.
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
      hfs_Course__c.hfs_ReleasedDate__c
    };
  }

  /**
   * @description Default ordering for course lists.
   * @return the ORDER BY clause (without the ORDER BY keyword)
   */
  public virtual override String getOrderBy() {
    return 'hfs_Category__c, Name';
  }

  /**
   * @description Returns all active courses ordered by category then name. Retired courses drop
   * out on the next load.
   * @return the active course records
   */
  public virtual List<hfs_Course__c> selectActiveCourses() {
    return (List<hfs_Course__c>) Database.query(
      newQueryFactory().setCondition('hfs_IsActive__c = true').toSOQL()
    );
  }
}
