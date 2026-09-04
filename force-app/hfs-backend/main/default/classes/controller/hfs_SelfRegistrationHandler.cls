/**
 * @description Custom self-registration handler implementing the current
 * Auth.ConfigurableSelfRegHandler lifecycle for Experience Cloud. Delegates to
 * the registration service so native self-registration is extended, not
 * replaced. Never trusts a client-supplied profile Id — the CCP profile is
 * resolved from configuration inside the service. Declared "without sharing"
 * because it runs in the elevated guest registration context.
 */
public without sharing class hfs_SelfRegistrationHandler implements Auth.ConfigurableSelfRegHandler {
    /**
     * @description Creates the inactive portal User (and its Account/Contact
     * chain) for a self-registering external partner. Returns the new User Id to
     * the platform, which then emails the standard set-password / registration
     * link the user clicks to activate the account.
     * @param accountId ignored — a new Account is created per registration (HFS-41)
     * @param profileId ignored — the least-privilege CCP profile is resolved from config
     * @param registrationAttributes map of standard User fields captured on the page
     * @param password ignored — the password is set by the user via the standard link
     * @return the created User Id
     */
    public Id createUser(
        Id accountId,
        Id profileId,
        Map<SObjectField, String> registrationAttributes,
        String password
    ) {
        String firstName = registrationAttributes.get(User.FirstName);
        String lastName = registrationAttributes.get(User.LastName);
        String email = registrationAttributes.get(User.Email);
        if (String.isBlank(email)) {
            email = registrationAttributes.get(User.Username);
        }
        String fullName = (String.isBlank(firstName) ? '' : firstName + ' ') + (lastName == null ? '' : lastName);
        hfs_RegistrationWrapper dto = new hfs_RegistrationWrapper();
        dto.name = fullName.trim();
        dto.email = email;
        hfs_RegistrationService service = new hfs_RegistrationServiceImpl();
        return service.provisionPartner(dto);
    }
}