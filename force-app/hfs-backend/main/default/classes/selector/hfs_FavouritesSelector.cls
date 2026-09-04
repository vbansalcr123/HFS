/**
 * @description Selector for hfs_Favorite__c. Centralizes all SOQL for the
 * favourites object. Exposes a count method for the Quick Actions "My
 * Favourites" tally; USER_MODE + owner filtering (supplied by the Service)
 * keeps the count scoped to the running user.
 */
public inherited sharing class hfs_FavouritesSelector extends fflib_SObjectSelector {
    /**
     * @description The SObject this selector queries.
     * @return hfs_Favorite__c SObjectType.
     */
    public Schema.SObjectType getSObjectType() {
        return hfs_Favorite__c.SObjectType;
    }

    /**
     * @description Base field list queried by the fflib base helpers.
     * @return The favourite fields.
     */
    public List<Schema.SObjectField> getSObjectFieldList() {
        return new List<Schema.SObjectField>{
            hfs_Favorite__c.Id,
            hfs_Favorite__c.Name,
            hfs_Favorite__c.OwnerId
        };
    }

    /**
     * @description Generic, injection-safe count. The Service supplies the WHERE
     * clause and bind map; USER_MODE enforces FLS/CRUD/sharing.
     * @param whereClause SOQL WHERE body (without the WHERE keyword), using named binds.
     * @param binds Bind variable map referenced by whereClause.
     * @return The number of matching favourite rows.
     */
    public Integer countFavouriteRecords(String whereClause, Map<String, Object> binds) {
        String query =
            'SELECT COUNT() FROM hfs_Favorite__c ' +
            (String.isBlank(whereClause) ? '' : 'WHERE ' + whereClause);
        return Database.countQueryWithBinds(
            query,
            binds == null ? new Map<String, Object>() : binds,
            AccessLevel.USER_MODE
        );
    }
}