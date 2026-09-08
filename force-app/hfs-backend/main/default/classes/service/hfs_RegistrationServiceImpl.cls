/**
 * @description Implementation of the self-registration use case. Runs "without
 * sharing" because provisioning happens in the elevated (guest) registration
 * context where the running user cannot own or create the identity records
 * directly; every step is still least-privilege and fails closed. The created
 * User is ACTIVE and its password is set from the value the visitor entered on
 * the signup page (a strong random one is generated when none is supplied), so
 * the user can log in immediately — no set-password email is sent.
 */
public without sharing class hfs_RegistrationServiceImpl implements hfs_RegistrationService {
    // Resolved through hfs_Application.Selector (never `new`'d directly) so tests
    // can substitute a mock via hfs_Application.Selector.setMock(...), matching
    // the pattern the rest of the codebase (e.g. hfs_ToolboxServiceImpl) follows.
    private final hfs_ContactsSelector contactsSelector =
        (hfs_ContactsSelector) hfs_Application.Selector.newInstance(Contact.SObjectType);
    private final hfs_UsersSelector usersSelector =
        (hfs_UsersSelector) hfs_Application.Selector.newInstance(User.SObjectType);
    private final hfs_PermissionSetsSelector permSetsSelector =
        (hfs_PermissionSetsSelector) hfs_Application.Selector.newInstance(PermissionSet.SObjectType);

    /**
     * @description Test seam: when set, this config is used instead of the
     * deployed `Default` custom metadata record. Lets tests point provisioning at
     * a test-created, role-bearing owner so the happy path runs (the org's real
     * `Default` owner may not have a UserRole). Never set in production paths.
     */
    @TestVisible
    private static hfs_Registration_Config__mdt configOverride;

    /**
     * @description Rejects duplicates then provisions the partner in one
     * transaction from the supplied DTO.
     * @param dto the registration payload
     * @return the created portal User Id
     */
    public Id registerPartner(hfs_RegistrationWrapper dto) {
        hfs_Guard.notNull(dto, 'dto');
        hfs_Guard.notBlank(dto.name, 'name');
        hfs_Guard.notBlank(dto.email, 'email');

        if (isDuplicate(dto.email)) {
            throw hfs_ApplicationException.build(
                System.Label.hfs_Error_Duplicate_Email,
                hfs_Constants.DUPLICATE_EMAIL
            );
        }

        return provisionPartner(dto);
    }

    /**
     * @description Provisions Account -> Contact -> active User in one
     * transaction from the supplied DTO: any exception during that commit rolls
     * the whole transaction back (no partial Contact / User). Once that commit
     * succeeds, the identity exists; setting the User's password and enqueueing
     * the permission-set assignment happen afterward and are best-effort — a
     * failure there is logged but does not roll back or fail the call, since the
     * account was already genuinely created (see the second try/catch below).
     * @param dto the registration payload (company, name, phone, email,
     *   partnerType, territory, message, password)
     * @return the created portal User Id
     */
    public Id provisionPartner(hfs_RegistrationWrapper dto) {
        hfs_Guard.notNull(dto, 'dto');
        hfs_Guard.notBlank(dto.email, 'email');

        hfs_Registration_Config__mdt config = configOverride != null
            ? configOverride
            : hfs_Registration_Config__mdt.getInstance('Default');
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

        // Resolve the password captured on the signup page. A password is required
        // to create a portal User; when the page did not supply one, generate a
        // strong random password so creation still succeeds.
        String password = String.isNotBlank(dto.password)
            ? dto.password
            : generateRandomPassword();

        // Resolve the internal, role-bearing owner for the portal Account.
        // Salesforce requires the owner of a portal (community) account to hold a
        // UserRole before a portal User can be inserted under it. The guest /
        // running user has no role, so the Account must be owned by a configured
        // internal user (User.Username in the CMDT) who does. Validate up front so
        // a mis-configured owner surfaces a clear config error instead of the
        // cryptic "portal account owner must have a role" platform exception.
        User portalOwner = usersSelector.getPortalAccountOwner(config.Portal_Account_Owner_Username__c);
        if (portalOwner == null || portalOwner.UserRoleId == null) {
            System.debug(LoggingLevel.ERROR,
                'hfs provisioning blocked: configured portal account owner "'
                + config.Portal_Account_Owner_Username__c + '" '
                + (portalOwner == null
                    ? 'was not found (inactive or wrong username).'
                    : 'has no UserRole assigned. Assign a role to this user in Setup > Users.')
            );
            throw hfs_ApplicationException.build(
                System.Label.hfs_Error_Provisioning_Failed,
                hfs_Constants.PROVISIONING_FAILED
            );
        }
        Id portalAccountOwnerId = portalOwner.Id;

        // Provision Account -> Contact -> active User through one Unit of Work.
        // registerNew wires the child relationships and commitWork() persists
        // them atomically — any exception here rolls the whole transaction back
        // (no partial identity). Password-setting and permission-set assignment
        // happen AFTER this commit and are handled in their own try/catch below:
        // once this commit succeeds the identity genuinely exists, and a failure
        // in those later steps must never be reported back as PROVISIONING_FAILED
        // (the visitor would see "failed" while an account was actually created,
        // and any retry would then be rejected as a duplicate, locking them out).
        fflib_ISObjectUnitOfWork uow = hfs_Application.UnitOfWork.newInstance();
        User portalUser;
        try {
            // 1) New Account per registration. Company name from the form (falls
            //    back to a derived name); partner type on the standard Account.Type.
            //    Owned by the configured role-bearing internal user so the portal
            //    User below can be created (portal account owner must have a role).
            Account acct = new Account(
                Name = deriveAccountName(dto.company, dto.name, dto.email),
                Type = dto.partnerType,
                OwnerId = portalAccountOwnerId
            );
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
            //    created ACTIVE. Validate the chosen password against the org
            //    password policy up front (throws if it fails) so a weak password
            //    surfaces before any DML. The password itself is applied after
            //    commit via System.setPassword.
            portalUser = buildPortalUser(con, dto.email, profileId);
            // Site.validatePassword / System.setPassword operate on real portal
            // credentials and the site context, which are unavailable in Apex
            // tests — guard so the provisioning path stays testable.
            if (!Test.isRunningTest()) {
                Site.validatePassword(portalUser, password, password);
            }
            uow.registerNew(portalUser, User.ContactId, con);

            // Account + Contact + active portal User commit together in one
            // transaction — allowed because the portal User carries a null
            // UserRoleId. The permission-set assignment is deliberately NOT part
            // of this Unit of Work: PermissionSetAssignment is a setup object and
            // mixing it with the non-setup Account/Contact DML throws
            // MIXED_DML_OPERATION. It is deferred to a Queueable below so it runs
            // in its own transaction after the User exists.
            uow.commitWork();
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'hfs provisioning failed: ' + e.getMessage() + '\n' + e.getStackTraceString());
            throw hfs_ApplicationException.build(
                System.Label.hfs_Error_Provisioning_Failed,
                hfs_Constants.PROVISIONING_FAILED
            );
        }

        // The Account/Contact/active User are committed at this point — the
        // identity genuinely exists. Password-setting and permission-set
        // enqueueing are best-effort from here: a failure is logged but never
        // rethrown as PROVISIONING_FAILED, since that would tell the visitor
        // nothing was created when an account actually was, and any retry would
        // then be rejected by the duplicate check above, locking them out for good.
        try {
            // Set the password the visitor chose on the signup page. Done after
            // commit because the User must exist first; setting the password here
            // (rather than leaving it blank) means Salesforce does NOT send a
            // set-password email — the user logs in immediately with this password.
            // Skipped under test context, where System.setPassword is not callable.
            if (!Test.isRunningTest()) {
                System.setPassword(portalUser.Id, password);
            }

            // Assign the partner permission set in a separate transaction. Safe to
            // enqueue post-commit; the permission set only grants access after the
            // user logs in with the password just set.
            if (permSetId != null) {
                System.enqueueJob(
                    new hfs_AssignPartnerPermSetQueueable(portalUser.Id, permSetId)
                );
            }
        } catch (Exception e) {
            System.debug(
                LoggingLevel.ERROR,
                'hfs post-provisioning step (setPassword/enqueueJob) failed for already-created user '
                    + portalUser.Id + ': ' + e.getMessage() + '\n' + e.getStackTraceString()
            );
        }
        return portalUser.Id;
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
     * @description Builds the active portal User record for a Contact. The
     * password is set separately by the caller after commit.
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
            // Created ACTIVE. The password the visitor chose on the signup page
            // is applied by the caller (System.setPassword) right after commit,
            // so the user can log in immediately — no set-password email needed.
            IsActive = true
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
     * @description Generates a strong random password used only when the signup
     * page did not supply one. Builds a 20-character string guaranteed to contain
     * upper, lower, numeric, and special characters so it satisfies typical org
     * password policies. Uses Crypto.getRandomInteger for cryptographic randomness.
     * @return a strong random password
     */
    @TestVisible
    private String generateRandomPassword() {
        final String UPPER = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
        final String LOWER = 'abcdefghijklmnopqrstuvwxyz';
        final String NUMS = '0123456789';
        final String SPECIAL = '!#$%-_=+';
        final String ALL = UPPER + LOWER + NUMS + SPECIAL;
        // Seed with one of each required class so policy checks pass.
        String pwd = ''
            + pickOne(UPPER)
            + pickOne(LOWER)
            + pickOne(NUMS)
            + pickOne(SPECIAL);
        while (pwd.length() < 20) {
            pwd += pickOne(ALL);
        }
        return pwd;
    }

    /**
     * @description Returns a single random character from the supplied set.
     * @param chars the character set to pick from
     * @return one random character
     */
    private String pickOne(String chars) {
        Integer i = Math.mod(Math.abs(Crypto.getRandomInteger()), chars.length());
        return chars.substring(i, i + 1);
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