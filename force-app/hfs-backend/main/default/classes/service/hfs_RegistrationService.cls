/**
 * @description Service interface for the self-registration use case. Owns the
 * transaction boundary: a duplicate check followed by the single-transaction
 * Account -> Contact -> inactive User + permission-set provisioning. Salesforce
 * emails the standard set-password / registration link on user creation.
 */
public interface hfs_RegistrationService {
    /**
     * @description Rejects duplicates then provisions the identity chain from the
     * supplied DTO in one transaction. Fails closed on any error.
     * @param dto the registration payload (name, email/username)
     */
    void registerPartner(hfs_RegistrationWrapper dto);

    /**
     * @description Provisions the identity chain from the supplied DTO. Reused by
     * the self-registration handler. The created User is inactive; Salesforce
     * emails the standard set-password link, and the account activates when
     * clicked.
     * @param dto the registration payload (company, name, phone, email,
     *   partnerType, territory, message)
     * @return the Id of the created portal User
     */
    Id provisionPartner(hfs_RegistrationWrapper dto);
}