/**
 * @description Selector for the standard Order object. Centralizes the SOQL used
 * by the Quick Actions "My Orders" tally. Customer Community Plus account-based
 * sharing scopes Order visibility to the user's account; USER_MODE enforces
 * CRUD/FLS at the query level.
 */
public inherited sharing class hfs_OrdersSelector extends fflib_SObjectSelector {
    /**
     * @description The SObject this selector queries.
     * @return Order SObjectType.
     */
    public Schema.SObjectType getSObjectType() {
        return Order.SObjectType;
    }

    /**
     * @description Base field list queried by the fflib base helpers.
     * @return The order fields.
     */
    public List<Schema.SObjectField> getSObjectFieldList() {
        return new List<Schema.SObjectField>{
            Order.Id,
            Order.OwnerId
        };
    }

    /**
     * @description Generic, injection-safe count. The Service supplies the WHERE
     * clause and bind map; USER_MODE + account-based sharing scope the result to
     * the running user's account.
     * @param whereClause SOQL WHERE body (without the WHERE keyword), using named binds.
     * @param binds Bind variable map referenced by whereClause.
     * @return The number of matching order rows.
     */
    public Integer countOrderRecords(String whereClause, Map<String, Object> binds) {
        String query =
            'SELECT COUNT() FROM Order ' +
            (String.isBlank(whereClause) ? '' : 'WHERE ' + whereClause);
        return Database.countQueryWithBinds(
            query,
            binds == null ? new Map<String, Object>() : binds,
            AccessLevel.USER_MODE
        );
    }
}