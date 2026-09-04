/**
 * @description Thin entry-point Controller for the self-registration LWC. The
 * single @AuraEnabled method validates via hfs_Guard, calls one Service
 * method, and always returns hfs_Response — never a raw SObject and never an
 * unhandled exception. Declared "with sharing" as the entry point.
 */
public with sharing class hfs_RegistrationController {
    /**
     * @description Registers a partner: validates input, rejects duplicates,
     * provisions the Account -> Contact -> inactive CCP User chain in one
     * transaction. Salesforce emails the standard set-password / registration
     * link so the user activates by clicking it.
     * @param dto the registration payload (name, email/username)
     * @return success with the echoed DTO (provisioned=true) or an error response
     */
    @AuraEnabled
    public static hfs_Response register(hfs_RegistrationWrapper dto) {
        try {
            hfs_Guard.notNull(dto, 'dto');
            hfs_RegistrationService service = new hfs_RegistrationServiceImpl();
            service.registerPartner(dto);
            dto.provisioned = true;
            return hfs_Response.success(dto);
        } catch (Exception e) {
            return hfs_Response.error(e);
        }
    }
}