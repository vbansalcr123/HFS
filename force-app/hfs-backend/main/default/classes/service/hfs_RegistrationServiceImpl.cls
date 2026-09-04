/**
 * @description Implementation of the self-registration use case. Runs "without
 * sharing" because provisioning happens in the elevated (guest) registration
 * context where the running user cannot own or create the identity records
 * directly; every step is still least-privilege and fails closed. The created
 * User is inactive — Salesforce sends the standard set-password / registration
 * link, and the account activates only when the user clicks it.
 */
public without sharing class hfs_RegistrationServiceImpl implements hfs_RegistrationService {
    private final hfs_ContactsGenericSelector contactsSelector = new hfs_ContactsGenericSelector();
    private final hfs_UsersSelector usersSelector = new hfs_UsersSelector();
    private final hfs_PermissionSetsSelector permSetsSelector = new hfs_PermissionSetsSelector();

    /**
     * @description Rejects duplicates then provisions the partner in one
     * transaction from the supplied DTO.
     * @param dto the registration payload
     */
    public void registerPartner(hfs_RegistrationWrapper dto) {
        hfs_Guard.notNull(dto, 'dto');
        hfs_Guard.notBlank(dto.name, 'name');
        hfs_Guard.notBlank(dto.email, 'email');

        if (isDuplicate(dto.email)) {
            throw hfs_ApplicationException.build(
                System.Label.hfs_Error_Duplicate_Email,
                hfs_Constants.DUPLICATE_EMAIL
            );
        }

        provisionPartner(dto);
    }

    /**
     * @description Provisions Account -> Contact -> inactive User + permission set
     * in one transaction from the supplied DTO. Any exception rolls the whole
     * transaction back — no partial Contact / User and no orphan permission-set
     * assignment. No password is set here; Salesforce emails the standard
     * set-password link.
     * @param dto the registration payload (company, name, phone, email,
     *   partnerType, territory, message)
     * @return the created portal User Id
     */
    public Id provisionPartner(hfs_RegistrationWrapper dto) {
        hfs_Guard.notNull(dto, 'dto');
        hfs_Guard.notBlank(dto.email, 'email');

        hfs_Registration_Config__mdt config = hfs_Registration_Config__mdt.getInstance('Default');
        if (config == null) {
            throw hfs_ApplicationException.build(
                System.Label.hfs_Error_Config_Missing,
                hfs_Constants.CONFIG_MISSING
            );
        }

        Id profileId = usersSelector.getProfileIdByName(config.Community_Plus_Profile_Name__c);
        if (profileId == null) {
            throw hfs_ApplicationException.build(
                System.Label.hfs_Error_Provisioning_Failed,
                hfs_Constants.PROVISIONING_FAILED
            );
        }
        Id permSetId = permSetsSelector.getPermissionSetIdByName(config.Partner_Permission_Set_Name__c);

        // Resolve the internal, role-bearing owner for the portal Account.
        // Salesforce requires the owner of a portal (community) account to hold a
        // UserRole before a portal User can be inserted under it. The guest /
        // running user has no role, so the Account must be owned by a configured
        // internal user (User.Username in the CMDT) who does.
        Id portalAccountOwnerId = usersSelector.getUserIdByUsername(config.Portal_Account_Owner_Username__c);

        // Provision Account -> Contact -> inactive User -> permission-set
        // assignment through one Unit of Work. registerNew wires the child
        // relationships and commitWork() persists everything atomically — any
        // exception rolls the whole transaction back (no partial identity, no
        // orphan assignment). No password is set here; Salesforce emails the
        // standard set-password link.
        fflib_ISObjectUnitOfWork uow = hfs_Application.UnitOfWork.newInstance();
        try {
            // 1) New Account per registration. Company name from the form (falls
            //    back to a derived name); partner type on the standard Account.Type.
            //    Owned by the configured role-bearing internal user so the portal
            //    User below can be created (portal account owner must have a role).
            Account acct = new Account(
                Name = deriveAccountName(dto.company, dto.name, dto.email),
                Type = dto.partnerType
            );
            if (portalAccountOwnerId != null) {
                acct.OwnerId = portalAccountOwnerId;
            }
            uow.registerNew(acct);

            // 2) Contact under the new Account, built inline here in the
            //    implementation. The full name is staged on LastName so the
            //    Domain can parse it; the Domain owns name parsing / defaulting,
            //    applied eagerly so the portal User build below sees the parsed
            //    First / Last name. Phone / territory / message land on standard
            //    Contact fields. The Service owns the DML.
            Contact con = new Contact(
                LastName = String.isBlank(dto.name) ? dto.email : dto.name.trim(),
                Email = dto.email,
                Phone = dto.phone,
                MailingState = dto.territory,
                Description = dto.message
            );
            ((hfs_ContactsDomain) hfs_Application.Domain.newInstance(new List<Contact>{ con }))
                .applyRegistrationDefaults();
            uow.registerNew(con, Contact.AccountId, acct);

            // 3) Portal User linked to the Contact (Customer Community Plus),
            //    created inactive — activated when the user clicks the emailed
            //    standard set-password / registration link.
            User portalUser = buildPortalUser(con, dto.email, profileId);
            uow.registerNew(portalUser, User.ContactId, con);

            // 4) Partner permission-set assignment in the same transaction.
            if (permSetId != null) {
                uow.registerNew(new PermissionSetAssignment(
                    AssigneeId = portalUser.Id,
                    PermissionSetId = permSetId
                ), PermissionSetAssignment.AssigneeId, portalUser);
            }

            uow.commitWork();
            return portalUser.Id;
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'hfs provisioning failed: ' + e.getMessage() + '\n' + e.getStackTraceString());
            throw hfs_ApplicationException.build(
                System.Label.hfs_Error_Provisioning_Failed,
                hfs_Constants.PROVISIONING_FAILED
            );
        }
    }

    /**
     * @description Assigns the partner permission set to a portal User in its own
     * Unit of Work. Retained as a @TestVisible seam; the main provisioning flow
     * registers the assignment on the shared Unit of Work in provisionPartner().
     * @param userId the created portal User Id
     * @param permSetId the partner permission set Id (nullable)
     */
    @TestVisible
    private void assignPartnerPermissionSet(Id userId, Id permSetId) {
        if (permSetId != null) {
            fflib_ISObjectUnitOfWork uow = hfs_Application.UnitOfWork.newInstance();
            uow.registerNew(new PermissionSetAssignment(
                AssigneeId = userId,
                PermissionSetId = permSetId
            ));
            uow.commitWork();
        }
    }

    /**
     * @description Duplicate detection across Contacts and Users by email / username.
     * @param email the email to check
     * @return true when a matching Contact or User already exists
     */
    private Boolean isDuplicate(String email) {
        List<Contact> contacts = contactsSelector.getContactsRecords(
            'Email = :email',
            new Map<String, Object>{ 'email' => email },
            new List<String>{ 'Id' }
        );
        if (!contacts.isEmpty()) {
            return true;
        }
        List<User> users = usersSelector.getUsersRecords(
            'Username = :username OR Email = :email',
            new Map<String, Object>{ 'username' => buildUsername(email), 'email' => email },
            new List<String>{ 'Id' }
        );
        return !users.isEmpty();
    }

    /**
     * @description Builds the inactive portal User record for a Contact.
     * @param con the linked Contact
     * @param email the registrant email
     * @param profileId the CCP profile Id
     * @return the unsaved User
     */
    private User buildPortalUser(Contact con, String email, Id profileId) {
        String firstName = String.isBlank(con.FirstName) ? 'Partner' : con.FirstName;
        String alias = email.substring(0, Math.min(8, email.length())).replaceAll('[^a-zA-Z0-9]', '');
        if (String.isBlank(alias)) {
            alias = 'ptnr';
        }
        return new User(
            ContactId = con.Id,
            ProfileId = profileId,
            Username = buildUsername(email),
            Email = email,
            FirstName = firstName,
            LastName = con.LastName,
            Alias = alias.left(8),
            CommunityNickname = alias.left(40) + String.valueOf(Math.mod(Math.abs(Crypto.getRandomInteger()), 1000)),
            TimeZoneSidKey = 'America/Denver',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            IsActive = false
        );
    }

    /**
     * @description Generates a unique portal username from the email.
     * @param email the registrant email
     * @return the generated username
     */
    private String buildUsername(String email) {
        return email + '.sinclairportal';
    }

    /**
     * @description Derives the new Account name — the company name when supplied,
     * otherwise the registrant name, otherwise a placeholder from the email.
     * @param company the company / business name
     * @param fullName the registrant name
     * @param email the registrant email
     * @return the Account name
     */
    private String deriveAccountName(String company, String fullName, String email) {
        if (String.isNotBlank(company)) {
            return company.trim();
        }
        return String.isBlank(fullName) ? ('Pending Partner - ' + email) : fullName;
    }
}