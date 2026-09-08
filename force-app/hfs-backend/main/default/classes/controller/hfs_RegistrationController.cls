/**
 * @description Thin entry-point Controller for the self-registration LWC. The
 * single @AuraEnabled method validates via hfs_Guard, calls one Service
 * method, and always returns hfs_Response — never a raw SObject and never an
 * unhandled exception. Declared "with sharing" as the entry point.
 */
public with sharing class hfs_RegistrationController {
    /**
     * @description Registers a partner: validates input, rejects duplicates,
     * provisions the Account -> Contact -> active CCP User chain in one
     * transaction, and sets the password the visitor entered on the signup page
     * so they can log in immediately (no set-password email).
     * @param dto the registration payload (name, email/username, password)
     * @return success with the echoed DTO (provisioned=true, password cleared) or
     *   an error response
     */
    @AuraEnabled
    public static hfs_Response register(hfs_RegistrationWrapper dto) {
        try {
            hfs_Guard.notNull(dto, 'dto');
            hfs_RegistrationService service = new hfs_RegistrationServiceImpl();
            service.registerPartner(dto);
            dto.provisioned = true;
            dto.password = null; // never echo the password back to the client
            return hfs_Response.success(dto);
        } catch (Exception e) {
            return hfs_Response.error(e);
        }
    }
}