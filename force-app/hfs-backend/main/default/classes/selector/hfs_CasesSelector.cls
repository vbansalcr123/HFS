/**
 * @description Selector for the standard Case object. Centralizes the SOQL used by the
 * Open Requests tile on the Home dashboard (HFS-32). Customer Community Plus account-based
 * sharing scopes Case visibility to the running user's account; USER_MODE enforces CRUD/FLS
 * at the query level, so a partner can only ever count their own open requests.
 */
public inherited sharing class hfs_CasesSelector extends fflib_SObjectSelector {
  /**
   * @description The SObject this selector queries.
   * @return Case SObjectType.
   */
  public Schema.SObjectType getSObjectType() {
    return Case.SObjectType;
  }

  /**
   * @description Base field list queried by the fflib base helpers.
   * @return The Case fields.
   */
  public List<Schema.SObjectField> getSObjectFieldList() {
    return new List<Schema.SObjectField>{
      Case.Id,
      Case.Status,
      Case.AccountId
    };
  }

  /**
   * @description Returns the running user's own open Cases (Status != 'Closed') for the given
   * account. USER_MODE + account-based sharing scope the result to the partner's own data.
   * The supporting-detail breakdown is derived in the service from Status.
   * @param accountId the partner account whose open requests are required
   * @return the partner's open Case records
   */
  public List<Case> selectOpenByAccount(Id accountId) {
    String query =
      'SELECT Id, Status FROM Case ' +
      'WHERE AccountId = :accountId AND Status != \'Closed\'';
    return (List<Case>) Database.queryWithBinds(
      query,
      new Map<String, Object>{ 'accountId' => accountId },
      AccessLevel.USER_MODE
    );
  }
}