/**
 * @description Selector for hfs_Download__c. Centralizes the SOQL used by the Downloads This
 * Month tile on the Home dashboard (HFS-32). Private OWD + account-based sharing scope download
 * visibility to the running user's account; USER_MODE enforces CRUD/FLS at the query level.
 */
public inherited sharing class hfs_DownloadsSelector extends fflib_SObjectSelector {
  /**
   * @description The SObject this selector queries.
   * @return hfs_Download__c SObjectType.
   */
  public Schema.SObjectType getSObjectType() {
    return hfs_Download__c.SObjectType;
  }

  /**
   * @description Base field list queried by the fflib base helpers.
   * @return The download fields.
   */
  public List<Schema.SObjectField> getSObjectFieldList() {
    return new List<Schema.SObjectField>{
      hfs_Download__c.Id,
      hfs_Download__c.hfs_Asset_Type__c,
      hfs_Download__c.hfs_Download_Date__c,
      hfs_Download__c.hfs_Account__c
    };
  }

  /**
   * @description Returns the running user's own downloads on/after the supplied month start
   * datetime (current-month filter). USER_MODE + sharing scope the result to the partner's own
   * data. The supporting-detail breakdown is derived in the service from Asset Type.
   * @param accountId the partner account whose downloads are required
   * @param monthStart the start of the current calendar month
   * @return the partner's current-month download records
   */
  public List<hfs_Download__c> selectCurrentMonthByAccount(
    Id accountId,
    Datetime monthStart
  ) {
    String query =
      'SELECT Id, hfs_Asset_Type__c FROM hfs_Download__c ' +
      'WHERE hfs_Account__c = :accountId AND hfs_Download_Date__c >= :monthStart';
    return (List<hfs_Download__c>) Database.queryWithBinds(
      query,
      new Map<String, Object>{
        'accountId' => accountId,
        'monthStart' => monthStart
      },
      AccessLevel.USER_MODE
    );
  }
}