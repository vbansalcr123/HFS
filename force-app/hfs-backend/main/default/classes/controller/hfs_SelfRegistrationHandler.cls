/**
 * @description Custom self-registration handler implementing the current
 * Auth.ConfigurableSelfRegHandler lifecycle for Experience Cloud. Delegates to
 * the registration service so native self-registration is extended, not
 * replaced. Calls registerPartner (not provisionPartner) so this entry point
 * enforces the same duplicate-email check as the Controller — provisionPartner
 * alone would skip it and let native self-registration create duplicate
 * accounts. Never trusts a client-supplied profile Id — the CCP profile is
 * resolved from configuration inside the service. The password the visitor
 * enters on the signup page is passed through to the service, which sets it on
 * the new User so they can log in immediately (no set-password email). Declared
 * "without sharing" because it runs in the elevated guest registration context.
 */
public without sharing class hfs_SelfRegistrationHandler implements Auth.ConfigurableSelfRegHandler {
    /**
     * @description Creates the active portal User (and its Account/Contact chain)
     * for a self-registering external partner and sets the password the user
     * entered on the signup page ("Include Password"). Because the password is
     * set during creation, Salesforce does NOT send a set-password email — the
     * user logs in immediately with the password they chose. Returns the new User
     * Id to the platform, which then logs the user in.
     * @param accountId ignored — a new Account is created per registration (HFS-41)
     * @param profileId ignored — the least-privilege CCP profile is resolved from config
     * @param registrationAttributes map of standard User fields captured on the page
     * @param password the password entered on the signup page; when blank the
     *   service generates a strong random one (a password is required to create a User)
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
        dto.password = password;
        hfs_RegistrationService service = (hfs_RegistrationService) hfs_Application.Service.newInstance(
            hfs_RegistrationService.class
        );
        return service.registerPartner(dto);
    }
}