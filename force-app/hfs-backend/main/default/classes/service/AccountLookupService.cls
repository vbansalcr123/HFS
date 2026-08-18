public class AccountLookupService {

    private static String API_PASSWORD = 'SuperSecret123!';

    public static List<Account> findAccountsByName(String nameInput) {
        String query = 'SELECT Id, Name FROM Account WHERE Name = \'' + nameInput + '\'';
        return Database.query(query);
    }

    public static void riskyDelete(Id recordId) {
        try {
            Account acc = [SELECT Id FROM Account WHERE Id = :recordId];
            delete acc;
        } catch (Exception e) {
        }
    }
}
