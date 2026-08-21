# Apex & LWC Development Standards — HFS Salesforce Project
*Reference doc for Claude Code — Draft v1*

## 0. Purpose

This doc is the coding-standards companion to `CI-CD-Pipeline-HFS-V1.docx`. That doc governs how code *moves* (branches, delta deploys, pipelines); this one governs how code is *written* — specifically Apex under the fflib (Apex Enterprise Patterns) architecture, LWC, and test classes. Claude Code should treat this as binding when generating or reviewing Apex/LWC, and flag when a request would violate it rather than silently complying.

Keep `CLAUDE.md` short (per your existing convention) and just point to this file — don't inline all of this into `CLAUDE.md` itself.

The proposed repository/directory structure implementing these conventions is up for review at [https://github.com/vbansalcr123/HFS](https://github.com/vbansalcr123/HFS).

---

## 1. Architecture at a Glance

Four layers, one direction of dependency. Nothing skips a layer downward, and nothing reaches back up.

| Layer | Responsibility | Talks to |
|---|---|---|
| **Selector** | All SOQL for one SObject. No business logic. | Database only |
| **Domain** | Object-level behavior: validation, defaulting, trigger logic. Operates on a `List<SObject>` (or `fflib_SObjectDomain`), never a single record. | Selector (for lookups it needs), Unit of Work (to register changes — never commits) |
| **Service** | Use-case / transaction boundary. This is what Controllers, Queueables, Batch, and other Services call. Owns the `commitWork()` call. | Domain, Selector, Unit of Work, other Services |
| **Unit of Work** | Batches and sequences all DML for one transaction, respecting relationship order. | Database only |

Request flow for a typical UI action:

```
LWC  →  Apex Controller (@AuraEnabled)  →  Service  →  Domain / Selector / UnitOfWork  →  DB
```

Everything is wired through `Application.cls` (Section 2) rather than `new`'d directly, so every layer can be mocked in tests. Everything the Controller returns to the LWC layer is wrapped in `hfs_Response` (Section 10).

---

## 2. The Application Factory (`Application.cls`)

One `Application` class for the whole package. Every Selector, Domain, and Service is resolved through it — this is what makes ApexMocks substitution possible in tests.

```apex
public class Application {

    public static final fflib_Application.UnitOfWorkFactory UnitOfWork =
        new fflib_Application.UnitOfWorkFactory(
            new List<SObjectType>{
                Account.SObjectType,
                hfs_Order__c.SObjectType
                // ...list in dependency/commit order
            });

    public static final fflib_Application.ServiceFactory Service =
        new fflib_Application.ServiceFactory(
            new Map<Type, Type>{
                hfs_OrderService.class => hfs_OrderServiceImpl.class
            });

    public static final fflib_Application.SelectorFactory Selector =
        new fflib_Application.SelectorFactory(
            new Map<SObjectType, Type>{
                hfs_Order__c.SObjectType => hfs_OrdersSelector.class
            });

    public static final fflib_Application.DomainFactory Domain =
        new fflib_Application.DomainFactory(
            Application.Selector,
            new Map<SObjectType, Type>{
                hfs_Order__c.SObjectType => hfs_Orders.Constructor.class
            });
}
```

**Rule:** no class outside `Application.cls` should ever call `new hfs_OrderServiceImpl()`, `new hfs_OrdersSelector()`, or the Domain constructor directly. Always go through `Application.Service.newInstance(...)`, `Application.Selector.newInstance(...)`, `Application.Domain.newInstance(...)`. This is the single change that makes everything downstream mockable.

---

## 3. Naming Conventions — Master Reference

**Every Apex and LWC file in this project carries the `hfs_` prefix.** For LWC bundles specifically: the platform requires component names to start with a lowercase letter, contain only alphanumeric/underscore characters, and never end with — or double up — an underscore. `hfs_shopifyOrderCard` satisfies all of that (starts with `h`, single non-trailing underscore).

| Artifact | Convention | Example |
|---|---|---|
| Selector class | `hfs_[PluralObject]Selector` | `hfs_OrdersSelector` |
| Domain class | `hfs_[PluralObject]` (plural — signals it operates on a set) | `hfs_Orders` |
| Service interface | `hfs_[UseCase]Service` | `hfs_OrderService` |
| Service implementation | `hfs_[UseCase]ServiceImpl` | `hfs_OrderServiceImpl` |
| Apex Controller (LWC-facing) | `hfs_[Feature]Controller` | `hfs_OrderController` |
| Shared Controller response wrapper | `hfs_Response` (one, project-wide) | `hfs_Response.success(payload)` |
| Shared exception base | `hfs_ApplicationException` (one, project-wide) | `hfs_OrderValidationException extends hfs_ApplicationException` |
| Error code constants (per domain, not one shared file) | `hfs_[Feature]ErrorCodes` | `hfs_OrderErrorCodes.ORDER_ALREADY_SUBMITTED` |
| Error message Custom Label (paired to a code) | `hfs_Error_[PascalCaseOfCode]` | `hfs_Error_Order_Already_Submitted` |
| Technical/guard-clause error codes (developer-facing, no Label) | `hfs_TechnicalErrorCodes` (one, project-wide) | `hfs_TechnicalErrorCodes.EMPTY_PAYLOAD` |
| Input-validation guard utility | `hfs_Guard` (one, project-wide) | `hfs_Guard.notNull(orderId, hfs_TechnicalErrorCodes.NULL_ARGUMENT)` |
| DTO (Controller ↔ LWC payloads) | `hfs_[Feature]DTO` | `hfs_OrderSummaryDTO` |
| External-system client/gateway (callouts) | `hfs_[System][Noun]Client` | `hfs_ExternalSystemClient` |
| Trigger | `hfs_[Object]Trigger` — singular, exactly one per object | `hfs_OrderTrigger` |
| Trigger handler | `hfs_[Object]TriggerHandler` | `hfs_OrderTriggerHandler` |
| Batch Apex | `hfs_[Feature]Batch` | `hfs_OrderCleanupBatch` |
| Queueable | `hfs_[Feature]Queueable` | `hfs_OrderSyncQueueable` |
| Schedulable | `hfs_[Feature]Scheduler` | `hfs_NightlySyncScheduler` |
| Test class | `hfs_[ClassName]Test` | `hfs_OrderServiceImplTest` |
| Test data factory | `hfs_TestDataFactory` (one shared utility) | `hfs_TestDataFactory.createOrders(5)` |
| Apex method (generic query) | `get[PluralObject]Records(whereClause, bindMap, fieldsToGet)` | `getOrderRecords(...)` |
| Apex method (generic write) | `create[PluralObject]Records` / `update[PluralObject]Records` | `createOrderRecords`, `updateOrderRecords` |
| Variables — collections | plural, purpose-revealing | `ordersToUpdate`, `accountIdToOrdersMap` |
| Constants | `UPPER_SNAKE_CASE` | `MAX_BATCH_SIZE` |
| Custom object / field API name | `hfs_[ObjectName]__c` / `hfs_[Field_Name]__c` — extends to everything newly developed (objects, fields, record types, permission sets, and other new metadata), not retroactive to anything already built | `hfs_Order__c`, `hfs_Total_Amount__c` |
| LWC bundle (folder + JS) | `hfs_[camelCaseName]` | `hfs_shopifyOrderStatusCard` |
| LWC in markup | kebab-case of the same name, underscore preserved | `<c-hfs_shopify-order-status-card>` |
| LWC Jest test | `[componentName].test.js` in `__tests__` | `hfs_shopifyOrderStatusCard.test.js` |
| Shared LWC utility module (cross-component) | `hfs_[purpose]Utils` — one focused module per functional area, not one project-wide catch-all | `hfs_dateUtils`, `hfs_cacheUtils` |
| Per-component labels/constants file | `utils.js` — colocated inside its own bundle, not separately prefixed | `lwc/hfs_shopifyOrderCard/utils.js` |

---

## 4. Selector Layer

Query methods are **generic**, not one bespoke `selectBy...` method per use case. The Service layer builds the `whereClause` and bind variables for whatever it needs; the Selector just knows how to run them safely.

```apex
public inherited sharing class hfs_OrdersSelector extends fflib_SObjectSelector {

    public List<Schema.SObjectField> getSObjectFieldList() {
        return new List<Schema.SObjectField>{
            hfs_Order__c.Id,
            hfs_Order__c.Name,
            hfs_Order__c.Status__c,
            hfs_Order__c.External_Reference_Id__c
        };
    }

    public Schema.SObjectType getSObjectType() {
        return hfs_Order__c.SObjectType;
    }

    /**
     * Generic, use-case-agnostic query entry point.
     *
     * HARD RULE: whereClause may only ever contain bind tokens (":paramName") —
     * never a literal value concatenated into the string. Every value referenced
     * in whereClause must have a matching entry in bindMap. This is what keeps a
     * fully generic query method safe from SOQL injection.
     */
    public List<hfs_Order__c> getOrderRecords(String whereClause, Map<String, Object> bindMap, List<String> fieldsToGet) {
        List<String> fields = (fieldsToGet != null && !fieldsToGet.isEmpty())
            ? fieldsToGet
            : new List<String>{ 'Id', 'Name', 'Status__c', 'External_Reference_Id__c' }; // default field set

        String query = 'SELECT ' + String.join(fields, ', ') + ' FROM hfs_Order__c';
        if (String.isNotBlank(whereClause)) {
            query += ' WHERE ' + whereClause;
        }

        Map<String, Object> binds = (bindMap != null) ? bindMap : new Map<String, Object>();
        return (List<hfs_Order__c>) Database.queryWithBinds(query, binds, AccessLevel.USER_MODE);
    }
}
```

Called from a Service method like this:

```apex
Map<String, Object> binds = new Map<String, Object>{ 'accountId' => accountId };
List<hfs_Order__c> orders = ordersSelector.getOrderRecords(
    'AccountId__c = :accountId',
    binds,
    new List<String>{ 'Id', 'Name', 'Status__c' }
);
```

Rules:
- **One Selector per SObject**, with one generic query method plus whatever the base `fflib_SObjectSelector` gives you for free (e.g. `selectSObjectsById` for straight Id lookups — no need to reinvent that one).
- `Database.queryWithBinds(..., AccessLevel.USER_MODE)` is the mechanism that makes a fully generic `whereClause` string safe — it takes bind variables as a `Map<String, Object>` rather than string concatenation, and `USER_MODE` keeps FLS/CRUD enforcement as the default.
- **Real tradeoff worth naming:** a generic method loses the self-documenting, one-query-per-method structure that makes it easy to see everywhere a given field is queried. If `fieldsToGet` is ever built from anything outside the Service layer's own control, validate it against a known field allow-list before it reaches the query string.

---

## 5. Domain Layer

Alongside the standard trigger-lifecycle overrides, Domain classes expose **generic create/update methods** driven by field-value maps.

```apex
public inherited sharing class hfs_Orders extends fflib_SObjectDomain {

    public hfs_Orders(List<hfs_Order__c> records) {
        super(records);
    }

    public class Constructor implements fflib_SObjectDomain.IConstructable {
        public fflib_SObjectDomain construct(List<SObject> sObjectList) {
            return new hfs_Orders((List<hfs_Order__c>) sObjectList);
        }
    }

    public override void onBeforeInsert() {
        defaultStatus();
    }

    public override void onValidate() {
        for (hfs_Order__c order : (List<hfs_Order__c>) getRecords()) {
            if (order.Total_Amount__c < 0) {
                order.addError('Total amount cannot be negative.');
            }
        }
    }

    private void defaultStatus() {
        for (hfs_Order__c order : (List<hfs_Order__c>) getRecords()) {
            if (order.Status__c == null) {
                order.Status__c = 'Draft';
            }
        }
    }

    public static List<hfs_Order__c> createOrderRecords(List<Map<String, Object>> recordData, fflib_ISObjectUnitOfWork uow) {
        List<hfs_Order__c> newRecords = new List<hfs_Order__c>();
        for (Map<String, Object> fieldValues : recordData) {
            hfs_Order__c record = new hfs_Order__c();
            for (String fieldName : fieldValues.keySet()) {
                record.put(fieldName, fieldValues.get(fieldName));
            }
            newRecords.add(record);
            uow.registerNew(record);
        }
        return newRecords;
    }

    public List<hfs_Order__c> updateOrderRecords(Map<Id, Map<String, Object>> fieldUpdatesByRecordId, fflib_ISObjectUnitOfWork uow) {
        List<hfs_Order__c> updated = new List<hfs_Order__c>();
        for (hfs_Order__c record : (List<hfs_Order__c>) getRecords()) {
            Map<String, Object> fieldValues = fieldUpdatesByRecordId.get(record.Id);
            if (fieldValues == null) { continue; }
            for (String fieldName : fieldValues.keySet()) {
                record.put(fieldName, fieldValues.get(fieldName));
            }
            uow.registerDirty(record);
            updated.add(record);
        }
        return updated;
    }
}
```

Rules:
- **Plural class name**, `hfs_Orders` not `hfs_Order`.
- **Never persists.** `createOrderRecords`/`updateOrderRecords` register against a passed-in `fflib_ISObjectUnitOfWork`; they never call `commitWork()`.
- **Real tradeoff worth naming:** field names as strings mean a typo is a runtime failure, not a compile error. Worth covering these two methods well in tests (Section 13).

---

## 6. Service Layer

```apex
public interface hfs_OrderService {
    void submitOrder(Id orderId);
}
```

```apex
public inherited sharing class hfs_OrderServiceImpl implements hfs_OrderService {

    public void submitOrder(Id orderId) {
        fflib_ISObjectUnitOfWork uow = Application.UnitOfWork.newInstance();

        hfs_OrdersSelector selector = (hfs_OrdersSelector) Application.Selector.newInstance(hfs_Order__c.SObjectType);
        List<hfs_Order__c> orders = selector.getOrderRecords(
            'Id = :orderId',
            new Map<String, Object>{ 'orderId' => orderId },
            null
        );

        hfs_Orders ordersDomain = (hfs_Orders) Application.Domain.newInstance(orders);
        ordersDomain.updateOrderRecords(
            new Map<Id, Map<String, Object>>{ orderId => new Map<String, Object>{ 'Status__c' => 'Submitted' } },
            uow
        );

        uow.commitWork();
    }
}
```

Rules:
- **Interface + Impl, always.**
- A Service method is a **use case**, not a CRUD wrapper.
- Service methods own the **transaction boundary**: one `commitWork()` per use case.
- **External-system callouts don't live in the Service class itself** — a dedicated client class (`hfs_ExternalSystemClient`) handles callout mechanics.
- **Services throw real, typed exceptions** (`hfs_OrderValidationException`, etc.) rather than knowing anything about `hfs_Response` — that wrapper is a Controller-boundary concept only (Section 10). A Service only catches when it's translating a lower-level exception into a domain-meaningful one (Section 11.1); otherwise it lets exceptions propagate. Keeping Services exception-based, not response-wrapper-based, is what lets a Queueable, Batch, or another Service call `hfs_OrderServiceImpl` without dragging an LWC-shaped response object into a non-UI context.

---

## 7. Unit of Work

- Obtain it via `Application.UnitOfWork.newInstance()` — never `new fflib_SObjectUnitOfWork(...)` directly outside `Application.cls`.
- `registerNew` / `registerDirty` / `registerDeleted` / `registerRelationship` can be called from Domain *or* Service methods.
- **Only the outermost Service method calls `commitWork()`.**
- Prefer the USER_MODE-aware DML path over the legacy `SimpleDML`.
- There's no per-object "Unit of Work class" to scaffold — `Application.UnitOfWork` is the single, project-wide factory registered once in Section 2.

---

## 8. Triggers

```apex
trigger hfs_OrderTrigger on hfs_Order__c (
    before insert, before update, before delete,
    after insert, after update, after delete, after undelete
) {
    hfs_OrderTriggerHandler.run();
}
```

```apex
public inherited sharing class hfs_OrderTriggerHandler {
    public static Boolean bypass = false;

    public static void run() {
        if (bypass) { return; }
        fflib_SObjectDomain.triggerHandler(hfs_Orders.class);
    }
}
```

Rules:
- One trigger per object, one `hfs_[Object]TriggerHandler`.
- The TriggerHandler owns trigger-context orchestration only — bypass switches, recursion guards — not business logic.
- All actual validation/defaulting logic still lives in the Domain class.
- Doesn't need its own dedicated test class by default — exercised implicitly through the Domain's real-DML test (Section 13).

---

## 9. Apex Controllers (LWC-facing)

Every `@AuraEnabled` method catches its own exceptions and always returns `hfs_Response` (Section 10) — nothing propagates unhandled out of a Controller method.

```apex
public with sharing class hfs_OrderController {

    @AuraEnabled(cacheable=true)
    public static hfs_Response getOrderSummaries(Id accountId) {
        try {
            hfs_OrdersSelector selector = (hfs_OrdersSelector) Application.Selector.newInstance(hfs_Order__c.SObjectType);
            List<hfs_Order__c> orders = selector.getOrderRecords(
                'AccountId__c = :accountId',
                new Map<String, Object>{ 'accountId' => accountId },
                new List<String>{ 'Id', 'Name', 'Status__c' }
            );
            return hfs_Response.success(hfs_OrderSummaryDTO.fromList(orders));
        } catch (Exception e) {
            return hfs_Response.error(e);
        }
    }

    @AuraEnabled
    public static hfs_Response submitOrder(Id orderId) {
        try {
            hfs_OrderService service = (hfs_OrderService) Application.Service.newInstance(hfs_OrderService.class);
            service.submitOrder(orderId);
            return hfs_Response.success(null);
        } catch (Exception e) {
            return hfs_Response.error(e);
        }
    }
}
```

Rules:
- Controllers are **thin**: call one Service (or Selector, for a pure read) method, wrap the result in `hfs_Response.success(...)`, wrap any exception in `hfs_Response.error(e)`.
- `@AuraEnabled(cacheable=true)` for reads only; plain `@AuraEnabled` for actions.
- Declare Controllers `with sharing` explicitly.
- The `payload` inside `hfs_Response.success(...)` is a DTO (`hfs_OrderSummaryDTO`), never a raw SObject.
- LWC components never call the Selector or Service layer directly — the Controller is the only door.

---

## 10. The `hfs_Response` Wrapper

Every `@AuraEnabled` method across every Controller returns the same shape, so every LWC component handles success/failure the same way instead of each one inventing its own return contract.

```apex
public with sharing class hfs_Response {

    @AuraEnabled public Boolean isSuccess;
    @AuraEnabled public Object payload;
    @AuraEnabled public String errorMessage;
    @AuraEnabled public String errorCode;

    private hfs_Response() {}

    public static hfs_Response success(Object payload) {
        hfs_Response response = new hfs_Response();
        response.isSuccess = true;
        response.payload = payload;
        return response;
    }

    public static hfs_Response error(String errorMessage) {
        return error(errorMessage, null);
    }

    public static hfs_Response error(String errorMessage, String errorCode) {
        hfs_Response response = new hfs_Response();
        response.isSuccess = false;
        response.errorMessage = errorMessage;
        response.errorCode = errorCode;
        return response;
    }

    /**
     * Safe default for a caught Exception. hfs_ApplicationException subclasses were
     * written deliberately for the end user to see, so their message — and whatever
     * errorCode was attached at the throw site (Section 11) — pass straight through.
     * Anything else (NullPointerException, DmlException, LimitException, etc.) is
     * unexpected/system-level — logged via Nebula Logger (Section 11.2), sanitized
     * to a generic message and code before it reaches the client.
     */
    public static hfs_Response error(Exception e) {
        if (e instanceof hfs_ApplicationException) {
            hfs_ApplicationException appEx = (hfs_ApplicationException) e;
            return error(appEx.getMessage(), appEx.errorCode);
        }
        Logger.error('Unexpected exception caught in hfs_Response.error', e);
        Logger.saveLog();
        return error('Something went wrong. Please try again or contact support.', hfs_CommonErrorCodes.UNEXPECTED_ERROR);
    }
}
```

Rules:
- **Fields:** `isSuccess` (Boolean, the primary machine-readable flag), `payload` (`Object` — whatever DTO/list the method returns on success), `errorMessage` (safe to display), `errorCode` (machine-readable — lets an LWC branch on e.g. `hfs_CommonErrorCodes.PERMISSION_DENIED` without string-matching a message; see Section 11 for where codes and messages actually come from).
- **This avoids a real Apex/LWC gotcha on purpose:** an uncaught exception thrown from an `@AuraEnabled` method gets auto-wrapped by the platform into a generic `AuraHandledException` whose message is stripped on the client *unless* the developer explicitly calls `.setMessage(...)` before throwing. `hfs_Response` sidesteps this entirely — real error detail travels inside the JSON payload, never through the exception mechanism, so nobody has to remember the `.setMessage()` step.
- **Message-safety split:** custom exceptions extend a shared `hfs_ApplicationException` base rather than `Exception` directly. This is what lets `hfs_Response.error(Exception e)` tell "a business exception someone deliberately wrote a safe message and code for" apart from "an unexpected system-level exception whose real message might leak implementation detail."
- **Boundary rule:** `hfs_Response` lives at the Controller layer only. Selector/Domain/Service classes never construct or return one — they throw typed exceptions like any other Apex code, and it's the Controller's job to catch those and translate them (Section 9). This keeps the Service/Domain/Selector layers usable from non-UI callers (Batch, Queueable, another Service) that shouldn't have to know an LWC-shaped wrapper exists.
- **Wire-cacheable caveat — read this before assuming `@wire` behaves as usual (full detail and code in Section 12):** because the Controller catches its own exceptions, a cacheable wired method almost always resolves into the wire's `data` branch, even on a business-level failure — the wire's built-in `error` branch stops being the error-handling mechanism. Components must check `data.isSuccess` inside `data` instead. This is a deliberate tradeoff for a uniform shape across every Controller, not an oversight, but it is a real divergence from how `@wire` is documented to work, and it's worth the team explicitly agreeing to it (see Section 17) rather than each dev discovering it independently.

---

## 11. General Apex Coding Standards

- **Sharing:** default new classes to `inherited sharing`. Reserve explicit `with sharing` for entry points (Controllers, top-of-transaction Queueables/Batch) and `without sharing` only with a one-line comment stating why.
- **Bulkification:** no SOQL or DML inside a `for` loop, ever.
- **Exceptions, error codes, and messages.** All custom exceptions extend `hfs_ApplicationException`, which carries an `errorCode` set at the throw site — this is what makes `hfs_Response.error(Exception e)` (Section 10) able to tell a deliberate, safe-to-show business exception apart from an unexpected one, and what lets the `errorCode` flow through to the LWC automatically.

  ```apex
  public virtual class hfs_ApplicationException extends Exception {
      public String errorCode;

      public hfs_ApplicationException withErrorCode(String errorCode) {
          this.errorCode = errorCode;
          return this;
      }
  }
  ```

  ```apex
  public class hfs_OrderValidationException extends hfs_ApplicationException {}
  ```

  **Error codes** are compile-time-safe Apex constants — not Custom Metadata, not raw string literals at the throw site. Split by domain rather than one shared file, so 3 people adding codes in parallel across 248 stories aren't all editing the same class:

  ```apex
  public class hfs_CommonErrorCodes {
      public static final String PERMISSION_DENIED = 'PERMISSION_DENIED';
      public static final String VALIDATION_ERROR = 'VALIDATION_ERROR';
      public static final String UNEXPECTED_ERROR = 'UNEXPECTED_ERROR';
  }
  ```
  ```apex
  public class hfs_OrderErrorCodes {
      public static final String ORDER_ALREADY_SUBMITTED = 'ORDER_ALREADY_SUBMITTED';
      public static final String ORDER_HAS_UNRESOLVED_ITEMS = 'ORDER_HAS_UNRESOLVED_ITEMS';
  }
  ```

  **Messages are Custom Labels**, not a hardcoded map and not Custom Metadata — this reuses the exact mechanism Section 12.2 already establishes for LWC-facing text, so it isn't a second parallel system. A Label reference (`System.Label.hfs_Error_X`) is checked at deploy time — reference one that doesn't exist and the deploy fails, which a Metadata-Type DeveloperName lookup wouldn't catch until runtime — and it comes with Translation Workbench support for free if that's ever needed. Name the Label after the code it pairs with: `hfs_Error_<PascalCaseOfCode>`.

  ```apex
  throw new hfs_OrderValidationException(System.Label.hfs_Error_Order_Already_Submitted)
      .withErrorCode(hfs_OrderErrorCodes.ORDER_ALREADY_SUBMITTED);
  ```

  For messages that need dynamic content, Custom Labels support `{0}`/`{1}` placeholders with `String.format`:

  ```apex
  String message = String.format(
      System.Label.hfs_Error_Order_Has_Unresolved_Items,
      new List<String>{ order.Name, String.valueOf(unresolvedCount) }
  );
  throw new hfs_OrderValidationException(message).withErrorCode(hfs_OrderErrorCodes.ORDER_HAS_UNRESOLVED_ITEMS);
  ```

  **Why not Custom Metadata for this:** CMDT's real advantages — translatable-ish structured records, edits without a full deploy — don't actually apply here. Everything ships through the same GitHub Actions pipeline regardless of metadata type, so CMDT isn't any faster to change than a Label or an Apex constant, and CMDT has no built-in translation support the way Labels do. It would become the right tool the moment an error needs more than a message — e.g. an external integration wanting to know whether a given failure is retryable, its backoff policy, or an HTTP-status equivalent — because that's a genuinely structured, multi-field record CMDT is built for and a Label can't represent. Worth revisiting then, not before.

  Throw specific exceptions, catch narrowly, never swallow silently.

- **Technical / guard-clause errors — a separate, developer-facing catalog.** Business errors above are things a real user needs to understand (order already submitted). A second, much smaller category is purely technical: empty payload, null argument, malformed input — identical in nature no matter which Controller hits them, never worded for an end user, and not worth a Custom Label since there's nothing to translate. These get one shared catalog with **hardcoded messages**, not Labels:

  ```apex
  public class hfs_TechnicalErrorCodes {

      public static final String EMPTY_PAYLOAD = 'HFS_TECH_001';
      public static final String NULL_ARGUMENT = 'HFS_TECH_002';
      public static final String INVALID_ID = 'HFS_TECH_003';
      public static final String MISSING_REQUIRED_PARAMETER = 'HFS_TECH_004';
      public static final String DESERIALIZATION_FAILED = 'HFS_TECH_005';

      private static final Map<String, String> MESSAGES = new Map<String, String>{
          EMPTY_PAYLOAD => 'Payload cannot be empty.',
          NULL_ARGUMENT => 'A required argument was null.',
          INVALID_ID => 'The Id provided is not valid for the expected SObject type.',
          MISSING_REQUIRED_PARAMETER => 'A required parameter was not provided.',
          DESERIALIZATION_FAILED => 'The provided payload could not be deserialized into the expected shape.'
      };

      public static String getMessage(String errorCode) {
          return MESSAGES.containsKey(errorCode) ? MESSAGES.get(errorCode) : 'Unrecognized technical error code: ' + errorCode;
      }
  }
  ```

  The constant value doubles as a stable, table-lookup-style code (`HFS_TECH_001`) while the constant *name* stays self-documenting in code (`EMPTY_PAYLOAD`) — you get a readable reference at the call site and an opaque, won't-change-if-the-wording-changes identifier on the wire, at the same time.

  A dedicated exception type keeps these visibly distinct from business exceptions, but it still extends `hfs_ApplicationException` so it flows through `hfs_Response` (Section 10) exactly the same way:

  ```apex
  public class hfs_TechnicalException extends hfs_ApplicationException {}
  ```

  **`hfs_Guard`** turns the common checks into one call instead of every Controller hand-writing its own null/empty check with its own slightly different wording:

  ```apex
  public inherited sharing class hfs_Guard {

      public static void notNull(Object value, String errorCode) {
          if (value == null) { fail(errorCode); }
      }

      public static void notBlank(String value, String errorCode) {
          if (String.isBlank(value)) { fail(errorCode); }
      }

      public static void notEmpty(List<Object> values, String errorCode) {
          if (values == null || values.isEmpty()) { fail(errorCode); }
      }

      private static void fail(String errorCode) {
          throw new hfs_TechnicalException(hfs_TechnicalErrorCodes.getMessage(errorCode))
              .withErrorCode(errorCode);
      }
  }
  ```

  Used at the top of a Controller method, before any real logic runs:

  ```apex
  @AuraEnabled
  public static hfs_Response submitOrder(Id orderId) {
      try {
          hfs_Guard.notNull(orderId, hfs_TechnicalErrorCodes.NULL_ARGUMENT);
          // ...real logic
          return hfs_Response.success(null);
      } catch (Exception e) {
          return hfs_Response.error(e);
      }
  }
  ```

  Most useful at the Controller boundary (that's where unvalidated client input first enters Apex), but `hfs_Guard` isn't Controller-only — any Service method can use it for the same kind of defensive check. Add new checks to `hfs_Guard` and new codes to `hfs_TechnicalErrorCodes` as real repeated patterns show up; don't pre-build every conceivable guard up front.

### 11.1 Where try/catch Belongs

Section 9/10 nailed this down for Controllers. The rest of the codebase needs the same clarity, especially the layers that don't have a Controller sitting downstream to catch for them.

| Layer | Catches? | Why |
|---|---|---|
| Selector | No | A query failure is systemic — there's nothing selector-level to recover from. |
| Domain | No — validation uses `addError()`, not exceptions (Section 5) | Different mechanism entirely; not an error path. |
| Service | Only to **translate** a low-level/technical exception into a domain-meaningful `hfs_ApplicationException`. Otherwise let it propagate. | Keeps the caller — Controller, Queueable, another Service — dealing with one typed, catchable exception instead of guessing what a dependency might throw. |
| External client (e.g. `hfs_ExternalSystemClient`) | Yes — catches transport-level exceptions (`CalloutException`, timeouts) and rethrows a typed one | So every caller gets a consistent exception type regardless of which raw failure the HTTP layer produced. |
| Controller | Always — the terminal catch, converts anything into `hfs_Response` (Section 10) | It's the boundary to the LWC; there's nowhere else for an error to go. |
| Queueable / Batch / Scheduled | Always — their **own** top-level try/catch | There is no Controller downstream. An uncaught exception here just triggers Salesforce's default Apex Exception Email and the failure is otherwise invisible to the application. |

**The external client is where technical and business errors actually meet.** A callout timeout is a technical detail; "we couldn't sync this record with the external system, try again shortly" is what the person who triggered the action needs to know. The client catches the low-level failure and re-throws a business exception (Label-backed message, per Section 11) — it doesn't let the raw `CalloutException` propagate up to the Controller, where it would just fall into `hfs_Response.error(Exception e)`'s generic "unexpected error" branch and lose the useful context:

```apex
public class hfs_ExternalIntegrationException extends hfs_ApplicationException {}
```
```apex
public class hfs_IntegrationErrorCodes {
    public static final String SYNC_FAILED = 'INTEGRATION_SYNC_FAILED';
}
```
```apex
public inherited sharing class hfs_ExternalSystemClient {

    public HttpResponse syncRecord(hfs_Order__c order) {
        try {
            return new Http().send(buildRequest(order));
        } catch (CalloutException e) {
            throw new hfs_ExternalIntegrationException(System.Label.hfs_Error_Integration_Sync_Failed)
                .withErrorCode(hfs_IntegrationErrorCodes.SYNC_FAILED);
        }
    }
}
```

**Async entry points need their own catch, logged to Nebula Logger (Section 11.2).** There's no Controller downstream to catch for them, so if this doesn't get logged here, it doesn't get logged anywhere except Salesforce's default Apex Exception Email.

```apex
public class hfs_OrderSyncQueueable implements Queueable, Database.AllowsCallouts {

    private List<Id> orderIds;

    public hfs_OrderSyncQueueable(List<Id> orderIds) {
        this.orderIds = orderIds;
    }

    public void execute(QueueableContext context) {
        try {
            hfs_OrderService service = (hfs_OrderService) Application.Service.newInstance(hfs_OrderService.class);
            service.syncOrders(orderIds);
        } catch (Exception e) {
            Logger.error('hfs_OrderSyncQueueable failed', e);
            Logger.saveLog();
            throw e; // still rethrow — keep Salesforce's failure email as a secondary safety net
        }
    }
}
```

### 11.2 Logging — Nebula Logger

**Decision: this project uses [Nebula Logger](https://github.com/jongpie/NebulaLogger) as the standard logging mechanism, project-wide.** This isn't a suggestion under evaluation — it's what every unexpected exception, and anything else worth surfacing beyond an ad hoc `System.debug()` during active development, goes through from here on. It's open source, actively maintained, built natively on the platform (Apex/LWC/Aura/Flow, no external dependencies), and persists log entries as real, queryable records (`Log__c`/`LogEntry__c`) instead of ephemeral debug logs that vanish after a day.

**Install as the unlocked package, not managed.** This is what Nebula Logger's own docs recommend as the default, and it matters concretely for this project: the plugin framework (including a ready-made Slack notification plugin — see below) isn't available in the managed package, and the managed package needs an explicit `parseStackTrace()` call to get stack traces that the unlocked package captures automatically. The tradeoff is namespace-free metadata living in the org rather than package-namespaced — a non-issue here since there's no other package namespace in play.

**This does touch the CI/CD pipeline, not just this doc** — worth tracking as a small addition to `CI-CD-Pipeline-HFS-V1.docx` rather than assuming it's free:
- **Scratch orgs** (PR validation and self-service, Sections 6 & 8 of the CI/CD doc): add Nebula Logger's unlocked package as a dependency in `sfdx-project.json` so `sf org create scratch` installs it automatically — one-time config, not a per-PR cost.
- **Dev/QA/UAT**: a one-time `sf package install --package <version-id>` against each environment, using the same JWT-authenticated CLI session already set up per Section 9 of the CI/CD doc. This is an occasional maintenance action (once now, again on deliberate version upgrades) — not part of every delta deploy.
- **Permission sets**: assign `LoggerLogCreator` to the CI integration user and to real users who need to generate logs; `LoggerAdmin` to whoever should view/manage the log data.

**Core API** — buffer entries at any log level, then flush once per transaction:

```apex
Logger.error('Order sync failed', e); // overload accepting the caught Exception directly
Logger.warn('Retrying sync after rate limit');
Logger.info('Order submitted successfully');
Logger.saveLog();
```

**Don't wrap it in an `hfs_` facade.** Every other cross-cutting piece in this doc (`hfs_Response`, `hfs_Guard`) got a thin project wrapper because it's *our* logic with room to evolve. Nebula Logger's own API is already clean, and it's stable, permissively-licensed, external vendor code — wrapping it just adds a layer with nothing to say. Call `Logger.*` directly.

**Per-environment log level control** comes from `LoggerSettings__c`, a custom hierarchy setting (org → profile → user) that ships with the package — worth knowing about since it's a concrete example of the right tool for "runtime-configurable, non-translatable settings," distinct from both the Custom Labels (Section 11) and the Custom Metadata question (Section 11) already discussed.

**Worth a look once this is in place, not required now:** Nebula Logger has a Slack notification plugin (unlocked-package-only) that can post to a channel on ERROR-level logs — a natural extension of the Slack alerting already built in Section 13 of the CI/CD strategy doc, using infrastructure that already exists.
- **No hardcoded Ids** (Record Type, Profile, User) — resolve via `Schema.SObjectType....getRecordTypeInfosByDeveloperName()`, Custom Metadata, or Custom Labels.
- **Config, not constants-in-code**, for anything that legitimately differs across Dev/QA/UAT/Production.
- **ApexDoc-style comments** on every public class and public method.
- Formatting matches whatever the PMD ruleset enforces on PR (Section 15).

---

## 12. LWC Component Standards

- **Composability — dumb components, smart containers.**
- **Reads via `@wire`, writes imperative.**
- **Business logic stays in Apex.**
- **Use base Lightning components** (`lightning-*`) before hand-rolling equivalents.
- **Performance:** avoid unbounded `@track`ing of large objects, debounce input-driven Apex calls, lazy-load heavy child components.
- **Testing:** every component gets a Jest spec under `__tests__`, using `@salesforce/apex` mocks for Apex, asserting on rendered DOM state.

### 12.1 Consuming `hfs_Response`

Every Apex call — imperative or wired — returns `hfs_Response`. Check `isSuccess` before touching `payload`; never assume success just because the Promise resolved or the wire returned `data`.

```javascript
// Imperative call (e.g. a button-triggered action)
handleSubmit() {
    submitOrder({ orderId: this.orderId })
        .then((response) => {
            if (response.isSuccess) {
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Success',
                    message: this.labels.orderSubmitted,
                    variant: 'success'
                }));
            } else {
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Error',
                    message: response.errorMessage,
                    variant: 'error'
                }));
            }
        })
        .catch((error) => {
            // Defensive backstop only — shouldn't normally fire, since the
            // Controller catches its own exceptions and always resolves
            // with an hfs_Response instead of throwing.
            this.dispatchEvent(new ShowToastEvent({
                title: 'Unexpected Error',
                message: reduceErrors(error),
                variant: 'error'
            }));
        });
}
```

```javascript
// @wire — note the caveat below
@wire(getOrderSummaries, { accountId: '$recordId' })
wiredOrders({ data, error }) {
    if (data) {
        if (data.isSuccess) {
            this.orders = data.payload;
        } else {
            this.errorMessage = data.errorMessage; // a business-level error, not a wire failure
        }
    } else if (error) {
        // Defensive backstop only — with hfs_Response, a wired method resolves
        // into `data` even on a business-level failure, so this branch is for
        // a genuinely unexpected failure that bypassed the Controller's own
        // try/catch entirely.
        this.errorMessage = reduceErrors(error);
    }
}
```

**Read this once, project-wide:** adopting `hfs_Response` means `@wire`'s built-in `error` branch is no longer the error-handling mechanism for business-level failures — `data.isSuccess` is. This is a one-time convention shift every component author needs to know, not a bug if `error` never seems to fire.

### 12.2 Labels, Constants, and Shared Utilities

**Per-component `utils.js`.** Every component bundle gets its own colocated `utils.js` holding that component's Custom Label imports and any local constants. The main component `.js` file imports from it rather than importing labels/constants directly:

```
lwc/hfs_shopifyOrderCard/
    hfs_shopifyOrderCard.html
    hfs_shopifyOrderCard.js
    hfs_shopifyOrderCard.css
    hfs_shopifyOrderCard.js-meta.xml
    utils.js              ← labels + constants for this component only
```

```javascript
// utils.js
import ORDER_SUBMITTED_LABEL from '@salesforce/label/c.hfs_Order_Submitted_Message';
import ORDER_FAILED_LABEL from '@salesforce/label/c.hfs_Order_Failed_Message';

export const labels = {
    orderSubmitted: ORDER_SUBMITTED_LABEL,
    orderFailed: ORDER_FAILED_LABEL
};

export const MAX_VISIBLE_ROWS = 10;
```

```javascript
// hfs_shopifyOrderCard.js
import { LightningElement } from 'lwc';
import { labels, MAX_VISIBLE_ROWS } from './utils';

export default class Hfs_shopifyOrderCard extends LightningElement {
    labels = labels;
    maxRows = MAX_VISIBLE_ROWS;
}
```

**Relative imports (`./utils`) only work within the same bundle folder** — this pattern is for a component's own private labels/constants, not for sharing code across components.

**Shared, focused utility modules for cross-component helpers — split by functional area from the start.** Rather than one `hfs_utils` catch-all that grows into a sprawling, unrelated pile, cross-component helpers live in small, single-purpose LWC "library" bundles — each its own bundle (JS-only, no HTML), named for exactly what it does:

```
lwc/hfs_dateUtils/hfs_dateUtils.js
lwc/hfs_cacheUtils/hfs_cacheUtils.js
lwc/hfs_errorUtils/hfs_errorUtils.js
```

```javascript
// hfs_dateUtils.js
export function formatShortDate(dateValue) {
    // ...
}
```

```javascript
// hfs_cacheUtils.js
const cache = new Map();

export function getOrSet(key, computeFn) {
    if (!cache.has(key)) {
        cache.set(key, computeFn());
    }
    return cache.get(key);
}
```

```javascript
// hfs_errorUtils.js
export function reduceErrors(errors) {
    // flattens wire/Apex error shapes into one readable string
}
```

```javascript
// any component
import { formatShortDate } from 'c/hfs_dateUtils';
import { reduceErrors } from 'c/hfs_errorUtils';
```

**Rule of thumb:** if two or more components need the same logic, it goes in the shared module for that functional area — start a new focused module if nothing existing fits; don't fold unrelated logic into an existing one just because it's already there. If it's specific to one component's labels or magic numbers, it stays local in that component's own `utils.js` (unchanged — see above).

---

## 13. Apex Test Class Standards

**Two-tier structure per class: one real end-to-end test, then mocked variations.**

**Tier 1 — exactly one real test.** No mocks anywhere in the chain: real `hfs_TestDataFactory` records, real DML, 200+ records (bulk-safety check), wrapped in `System.runAs()` with a restricted-permission test user.

**Tier 2 — mocked variations.** Stub the Selector/Domain/Service/UnitOfWork with ApexMocks and vary only the arguments under test.

```apex
@isTest
private class hfs_OrderServiceImplTest {

    @isTest
    static void submitOrder_realDataRestrictedUser_updatesStatusAndEnforcesPermissions() {
        List<hfs_Order__c> orders = hfs_TestDataFactory.createOrders(200);
        insert orders;

        User restrictedUser = hfs_TestDataFactory.createUserWithPermissionSet('HFS_Order_Submitter');

        Test.startTest();
        System.runAs(restrictedUser) {
            new hfs_OrderServiceImpl().submitOrder(orders[0].Id);
        }
        Test.stopTest();

        hfs_Order__c result = [SELECT Status__c FROM hfs_Order__c WHERE Id = :orders[0].Id];
        System.Assert.areEqual('Submitted', result.Status__c, 'Order should be submitted by a user with the right permission set.');
    }

    @isTest
    static void submitOrder_orderAlreadySubmitted_throwsValidationException() {
        fflib_ApexMocks mocks = new fflib_ApexMocks();
        hfs_OrdersSelector selectorMock = (hfs_OrdersSelector) mocks.mock(hfs_OrdersSelector.class);
        fflib_ISObjectUnitOfWork uowMock = (fflib_ISObjectUnitOfWork) mocks.mock(fflib_SObjectUnitOfWork.class);

        hfs_Order__c alreadySubmitted = new hfs_Order__c(
            Id = fflib_IDGenerator.generate(hfs_Order__c.SObjectType),
            Status__c = 'Submitted'
        );

        mocks.startStubbing();
        mocks.when(selectorMock.getOrderRecords(
            (String) fflib_Match.anyObject(),
            (Map<String, Object>) fflib_Match.anyObject(),
            (List<String>) fflib_Match.anyObject()
        )).thenReturn(new List<hfs_Order__c>{ alreadySubmitted });
        mocks.stopStubbing();

        Application.Selector.setMock(selectorMock);
        Application.UnitOfWork.setMock(uowMock);

        try {
            new hfs_OrderServiceImpl().submitOrder(alreadySubmitted.Id);
            System.Assert.fail('Expected hfs_OrderValidationException.');
        } catch (hfs_OrderValidationException e) {
            System.Assert.isTrue(e.getMessage().contains('already submitted'), 'Exception message should explain why.');
        }

        ((fflib_ISObjectUnitOfWork) mocks.verify(uowMock, 0)).commitWork();
    }
}
```

Rules:
- **Naming:** `hfs_[ClassName]Test`; test methods as `methodUnderTest_condition_expectedResult`.
- **Test data via `hfs_TestDataFactory`.**
- No `SeeAllData=true`; no hardcoded Ids.
- Assert meaningfully: `System.Assert.areEqual(expected, actual, 'message')` on Tier 1's outcome; `mocks.verify(...)` on Tier 2's interactions.
- **Controller tests assert directly on `hfs_Response`** — `System.Assert.isTrue(response.isSuccess, ...)` / `System.Assert.areEqual('Submitted', ((hfs_OrderSummaryDTO) response.payload).status, ...)` for the success path, and `System.Assert.isFalse(response.isSuccess, ...)` plus a check on `errorMessage`/`errorCode` for the failure path — same two-tier structure as any other class.
- Coverage: 75% is the CI gate floor, not the target.

### 13.1 Mocking Reference by Layer

| Dependency | Mock it with | Register it with |
|---|---|---|
| Selector | `(hfs_OrdersSelector) mocks.mock(hfs_OrdersSelector.class)` | `Application.Selector.setMock(selectorMock)` |
| Domain | `(hfs_Orders) mocks.mock(hfs_Orders.class)` | `Application.Domain.setMock(domainMock)` |
| Service | `(hfs_OrderService) mocks.mock(hfs_OrderService.class)` | `Application.Service.setMock(hfs_OrderService.class, serviceMock)` |
| Unit of Work | `(fflib_ISObjectUnitOfWork) mocks.mock(fflib_SObjectUnitOfWork.class)` | `Application.UnitOfWork.setMock(uowMock)` |

Notes:
- **Domain mocking is the one you'll reach for least.** Tier 1 tests deliberately run Domain logic against real records. Double-check `Application.Domain.setMock(...)`'s exact signature against the fflib version actually installed before relying on it.
- Mock the Service layer when testing a Controller in isolation, or when Service A calls Service B.
- Always `mocks.startStubbing()` / `mocks.stopStubbing()` around `mocks.when(...)`, and `mocks.verify(mock, times)` when asserting an interaction happened.

---

## 14. Scaffolding Templates — New Object Checklist

Placeholders: `{Object}` = singular PascalCase name, `{Objects}` = plural, `{ObjectApi}` = full API name — remember this now includes the `hfs_` prefix for a newly created object (e.g. `hfs_Contract__c`, Section 3).

### 14.1 Selector — *Section 4*
```apex
public inherited sharing class hfs_{Objects}Selector extends fflib_SObjectSelector {

    public List<Schema.SObjectField> getSObjectFieldList() {
        return new List<Schema.SObjectField>{ {ObjectApi}.Id, {ObjectApi}.Name };
    }

    public Schema.SObjectType getSObjectType() {
        return {ObjectApi}.SObjectType;
    }

    public List<{ObjectApi}> get{Objects}Records(String whereClause, Map<String, Object> bindMap, List<String> fieldsToGet) {
        List<String> fields = (fieldsToGet != null && !fieldsToGet.isEmpty())
            ? fieldsToGet
            : new List<String>{ 'Id', 'Name' };

        String query = 'SELECT ' + String.join(fields, ', ') + ' FROM {ObjectApi}';
        if (String.isNotBlank(whereClause)) {
            query += ' WHERE ' + whereClause;
        }

        Map<String, Object> binds = (bindMap != null) ? bindMap : new Map<String, Object>();
        return (List<{ObjectApi}>) Database.queryWithBinds(query, binds, AccessLevel.USER_MODE);
    }
}
```

### 14.2 Domain — *Section 5*
```apex
public inherited sharing class hfs_{Objects} extends fflib_SObjectDomain {

    public hfs_{Objects}(List<{ObjectApi}> records) {
        super(records);
    }

    public class Constructor implements fflib_SObjectDomain.IConstructable {
        public fflib_SObjectDomain construct(List<SObject> sObjectList) {
            return new hfs_{Objects}((List<{ObjectApi}>) sObjectList);
        }
    }

    public static List<{ObjectApi}> create{Objects}Records(List<Map<String, Object>> recordData, fflib_ISObjectUnitOfWork uow) {
        // see Section 5
    }

    public List<{ObjectApi}> update{Objects}Records(Map<Id, Map<String, Object>> fieldUpdatesByRecordId, fflib_ISObjectUnitOfWork uow) {
        // see Section 5
    }
}
```

### 14.3 Service — *Section 6*
```apex
public interface hfs_{Object}Service {
    // Name methods for actual use cases.
}
```
```apex
public inherited sharing class hfs_{Object}ServiceImpl implements hfs_{Object}Service {
    // One commitWork() per use case. On failure, throw an hfs_ApplicationException
    // subclass with a code from hfs_{Object}ErrorCodes and a message from a paired
    // hfs_Error_[Code] Custom Label — see Section 11.
}
```

If this object needs its own error codes, add `hfs_{Object}ErrorCodes` alongside it (Section 11) — don't add them to another domain's file or a shared catch-all.

### 14.4 Trigger + TriggerHandler — *Section 8*
```apex
trigger hfs_{Object}Trigger on {ObjectApi} (
    before insert, before update, before delete,
    after insert, after update, after delete, after undelete
) {
    hfs_{Object}TriggerHandler.run();
}
```
```apex
public inherited sharing class hfs_{Object}TriggerHandler {
    public static Boolean bypass = false;

    public static void run() {
        if (bypass) { return; }
        fflib_SObjectDomain.triggerHandler(hfs_{Objects}.class);
    }
}
```

### 14.5 Controller — *Sections 9 & 10* (only if the LWC layer needs it)
```apex
public with sharing class hfs_{Object}Controller {

    @AuraEnabled(cacheable=true)
    public static hfs_Response get{Objects}Summaries(/* params */) {
        try {
            // hfs_Guard.notNull(...) / .notBlank(...) for basic input checks first
            // Selector → DTO → hfs_Response.success(...)
        } catch (Exception e) {
            return hfs_Response.error(e);
        }
    }
}
```

### 14.6 Register with `Application.cls` — *Section 2*
```apex
{ObjectApi}.SObjectType                                          // UnitOfWorkFactory list
{ObjectApi}.SObjectType => hfs_{Objects}Selector.class            // SelectorFactory map
{ObjectApi}.SObjectType => hfs_{Objects}.Constructor.class        // DomainFactory map
hfs_{Object}Service.class => hfs_{Object}ServiceImpl.class        // ServiceFactory map
```

### 14.7 Tests — *Section 13*
- `hfs_{Objects}SelectorTest`
- `hfs_{Objects}Test` (Domain — real records, no mocks)
- `hfs_{Object}ServiceImplTest` — Tier 1 + Tier 2
- `hfs_{Object}ControllerTest` (if a Controller was added) — assert on `hfs_Response.isSuccess`/`payload`/`errorMessage`
- Add a `create{Objects}(Integer count)` method to `hfs_TestDataFactory`

---

## 15. Static Analysis Tie-In

- **PMD (via Salesforce Code Analyzer / `sf code-analyzer`)** against `**/*.cls` and `**/*.trigger`, at minimum `bestpractices` and `security`.
- **ESLint** with `@salesforce/eslint-config-lwc` against `**/lwc/**/*.js`.
- Worth a lightweight custom check enforcing the `hfs_` prefix on new class/trigger/LWC names.

---

## 16. PR Definition-of-Done Checklist

- [ ] Every new SObject-specific query lives in that object's Selector, using the generic `get[Object]Records(...)` pattern.
- [ ] No Domain method calls `commitWork()`; only the owning Service method does.
- [ ] Every new class is wired through `Application.cls`.
- [ ] All new files — Apex and LWC — carry the `hfs_` prefix.
- [ ] Each object's trigger delegates to its `hfs_[Object]TriggerHandler`.
- [ ] New object work followed the Section 14 checklist in full.
- [ ] **Every `@AuraEnabled` method returns `hfs_Response` and wraps its body in try/catch** — nothing propagates as a raw/unhandled exception.
- [ ] All custom exceptions extend `hfs_ApplicationException`, not `Exception` directly, and set `errorCode` via `.withErrorCode(...)` at the throw site.
- [ ] New error codes go in the right domain's `hfs_[Feature]ErrorCodes` class (not a raw string literal, not a new shared catch-all file) with a paired `hfs_Error_[PascalCaseOfCode]` Custom Label — check both don't already exist for the same logical error before adding new ones.
- [ ] Generic input checks (null/blank/empty payload) use `hfs_Guard` + `hfs_TechnicalErrorCodes` instead of a hand-written, one-off null check — no ad hoc `if (x == null) return hfs_Response.error('...')` with bespoke wording.
- [ ] Try/catch placement follows Section 11.1 by layer — Selector/Domain don't catch, Services only catch to translate, external clients catch-and-retype, Controllers always catch, and **every Queueable/Batch/Scheduled entry point has its own top-level try/catch** (there's no Controller downstream for async work).
- [ ] Unexpected/system-level exceptions are logged via `Logger.error(...)` + `Logger.saveLog()` (Section 11.2) — not a bare `System.debug`, and not swallowed silently.
- [ ] LWC components consuming Apex check `response.isSuccess` (imperative) or `data.isSuccess` (wire) before touching `payload`.
- [ ] Component-specific labels/constants live in that component's own `utils.js`; cross-component helpers live in the right focused `hfs_[purpose]Utils` module — not duplicated, and not dumped into an unrelated existing one.
- [ ] Test class has the Tier 1 real/permission/bulk test plus Tier 2 mocked variations.
- [ ] No hardcoded Ids, no `SeeAllData=true`.
- [ ] `sf code-analyzer` / PMD and ESLint pass locally before pushing.

---

## 17. Open Items — Not Yet Decided

- **Field-name-string safety for the generic create/update Domain methods.** No allow-list/validation yet; worth adding once more than one or two Services use the pattern.
- **External-system client error/retry contract.** The exception-typing half is settled (Section 11.1 — catch transport failures, rethrow a typed `hfs_ApplicationException`). What's still open: retry/backoff policy for a failed sync — does the Queueable requeue itself, how many attempts, what backoff — and whether that policy differs for a rate-limit response versus a genuine failure. Worth deciding before the first real integration client gets built.
- **Structured, multi-field error metadata.** The current design (Section 11) covers a code + a message. If any integration needs richer per-error metadata — retryable Y/N, backoff policy, an HTTP-status equivalent — that's the trigger to introduce a Custom Metadata Type for that specific case, layered on top of the existing code, not a replacement for it.
- **Nebula Logger installation across environments.** The tool decision is made (Section 11.2) — installing it isn't. Package install against Dev/QA/UAT and adding it to the scratch org dependency config are still pending action items against the CI/CD pipeline, not something settled by this doc alone.
- **Nebula Logger's Slack plugin** (Section 11.2) is a genuinely low-effort win given the Slack infrastructure already built in the CI/CD doc, but it's a separate decision from the base logging choice and hasn't been evaluated yet.
- **`hfs_Response.payload` typed as `Object`, not a pre-serialized JSON string.** This is the more ergonomic choice for LWC and is expected to serialize correctly for nested DTOs on this org's API version, but it hasn't been proven against a deeply nested or `Map`-heavy payload yet. Worth a throwaway spike before this becomes the pattern behind every one of the project's Controllers, given how central it now is.
- **No batch/partial-success shape yet.** Any bulk integration sync (some records succeed, some fail within the same call) will need one — `hfs_Response`'s binary `isSuccess` doesn't represent that. Worth designing an `hfs_BatchResponse` (or an agreed `List<hfs_Response>` convention) before that work starts, rather than retrofitting it under deadline pressure.
- **Whether cacheable `@wire` methods should use `hfs_Response` at all**, versus staying "native" (let real exceptions throw, rely on the wire's built-in `error` channel) and reserving `hfs_Response` for imperative writes only. This doc defaults to uniform usage since that's what was asked, but the tradeoff in Section 10/12 is real enough that it's worth the team explicitly signing off on it rather than each dev discovering the `error`-branch-never-fires behavior independently.
- **Client-side API response caching — backlog, not being built now.** Plan: identify which `@AuraEnabled` Controller methods get called most frequently across different pages/components, and cache their responses in browser local/session storage to cut down on redundant server round-trips, with the cached data encrypted. Two things worth thinking through when this is actually picked up (not solved here): (1) cache invalidation — TTL-based expiry vs. explicit invalidation when the underlying data changes, and how that interacts with the `hfs_Response` shape; (2) client-side encryption has a real ceiling — the decryption key has to be reachable by the same JS the encryption is nominally protecting data from, so this is realistically obfuscation/defense-in-depth against casual inspection of storage, not a genuine security boundary. Fine as a reason to reduce exposure, not a reason to treat otherwise-sensitive data as safe to cache client-side.
