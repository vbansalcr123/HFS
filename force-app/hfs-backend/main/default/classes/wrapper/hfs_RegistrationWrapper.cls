/**
 * @description Controller-to-LWC wrapper for the self-registration flow. Carries
 * only the non-sensitive registration fields captured on the request-access
 * form (company, name, phone, email/username, partner type, territory, message).
 * The password captured on the signup page is carried for provisioning only and
 * is never persisted — it is nulled by the controller before the DTO is echoed
 * back, and consumed only by Site.validatePassword / System.setPassword during
 * user creation.
 */
public class hfs_RegistrationWrapper {
    /** @description Registrant company / business name (maps to Account.Name). */
    @AuraEnabled
    public String company { get; set; }

    /** @description Registrant full name. */
    @AuraEnabled
    public String name { get; set; }

    /** @description Registrant phone number (maps to Contact.Phone). */
    @AuraEnabled
    public String phone { get; set; }

    /** @description Registrant email / username. */
    @AuraEnabled
    public String email { get; set; }

    /** @description Partner type (Dealer / Distributor); persisted on Account.Type. */
    @AuraEnabled
    public String partnerType { get; set; }

    /** @description Territory / state (maps to Contact.MailingState). */
    @AuraEnabled
    public String territory { get; set; }

    /** @description Free-text "How can we help?" note (maps to Contact.Description). */
    @AuraEnabled
    public String message { get; set; }

    /**
     * @description Password captured on the signup page. @AuraEnabled so the
     * custom self-registration LWC can send it, but it is WRITE-ONLY in practice:
     * the controller nulls it out before echoing the DTO back, and it is never
     * persisted — only handed to Site.validatePassword / System.setPassword during
     * user creation. When blank the service generates a strong random password.
     */
    @AuraEnabled
    public String password { get; set; }

    /** @description True when the partner was provisioned successfully. */
    @AuraEnabled
    public Boolean provisioned { get; set; }

    /** @description Default constructor. */
    public hfs_RegistrationWrapper() {
        this.provisioned = false;
    }
}