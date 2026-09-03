public with sharing class ScratchReviewBotTest {
  public static List<Account> selectAccountsForContacts(
    List<Contact> contacts
  ) {
    List<Account> results = new List<Account>();
    for (Contact c : contacts) {
      results.addAll([SELECT Id, Name FROM Account WHERE Id = :c.AccountId]);
    }
    return results;
  }
}
