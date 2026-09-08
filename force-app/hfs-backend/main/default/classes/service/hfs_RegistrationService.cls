/**
 * @description Service interface for the self-registration use case. Owns the
 * transaction boundary: a duplicate check followed by the single-transaction
 * Account -> Contact -> active User + permission-set provisioning. The password
 * captured on the signup page is set on the new User during creation, so the
 * user can log in immediately and no set-password email is sent.
 */
public interface hfs_RegistrationService {
    /**
     * @description Rejects duplicates then provisions the identity chain from the
     * supplied DTO in one transaction. Fails closed on any error.
     * @param dto the registration payload (name, email/username)
     * @return the created portal User Id
     */
    Id registerPartner(hfs_RegistrationWrapper dto);

    /**
     * @description Provisions the identity chain from the supplied DTO and sets
     * the User's password to the value captured on the signup page. Reused by the
     * self-registration handler. The created User is active with the chosen
     * password, so the user can log in immediately (no set-password email).
     * @param dto the registration payload (company, name, phone, email,
     *   partnerType, territory, message, password)
     * @return the Id of the created portal User
     */
    Id provisionPartner(hfs_RegistrationWrapper dto);
}