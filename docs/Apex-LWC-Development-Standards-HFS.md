# Apex & LWC Development Standards — HFS Salesforce Project

_Reference doc for Claude Code — Draft v2_

## 0. Purpose

This doc is the coding-standards companion to `CI-CD-Pipeline-HFS-V1.docx`. That doc governs how code _moves_ (branches, delta deploys, pipelines); this one governs how code is _written_ — specifically Apex under the fflib (Apex Enterprise Patterns) architecture, LWC, and test classes. Claude Code should treat this as binding when generating or reviewing Apex/LWC, and flag when a request would violate it rather than silently complying.

Keep `CLAUDE.md` short (per your existing convention) and just point to this file — don't inline all of this into `CLAUDE.md` itself.

The proposed repository/directory structure implementing these conventions is up for review at [https://github.com/vbansalcr123/HFS](https://github.com/vbansalcr123/HFS).

---

## 1. Architecture at a Glance

Four layers, one direction of dependency. Nothing skips a layer downward, and nothing reaches back up.

| Layer            | Responsibility                                                                                                                                 | Talks to                                                                            |
| ---------------- | ---------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------- |
| **Selector**     | All SOQL for one SObject. No business logic.                                                                                                   | Database only                                                                       |
| **Domain**       | Object-level behavior: validation, defaulting, trigger logic. Operates on a `List<SObject>` (or `fflib_SObjectDomain`), never a single record. | Selector (for lookups it needs), Unit of Work (to register changes — never commits) |
| **Service**      | Use-case / transaction boundary. This is what Controllers, Queueables, Batch, and other Services call. Owns the `commitWork()` call.           | Domain, Selector, Unit of Work, other Services                                      |
| **Unit of Work** | Batches and sequences all DML for one transaction, respecting relationship order.                                                              | Database only                                                                       |

Request flow for a typical UI action:

```
LWC  →  Apex Controller (@AuraEnabled)  →  Service  →  Domain / Selector / UnitOfWork  →  DB
```

Everything is wired through `hfs_Application.cls` (Section 2) rather than `new`'d directly, so every layer can be mocked in tests. Everything the Controller returns to the LWC layer is wrapped in `hfs_Response` (Section 10).

---

## 2. The Application Factory (`hfs_Application.cls`)

One `hfs_Application` class for the whole package. Every Selector, Domain, and Service is resolved through it — this is what makes ApexMocks substitution possible in tests.

```apex
public class hfs_Application {
  public static final UnitOfWorkFactory UnitOfWork = new UnitOfWorkFactory();
  public static final SelectorFactory Selector = new SelectorFactory();
  public static final ServiceFactory Service = new ServiceFactory();
  public static final DomainFactory Domain = new DomainFactory();

  public class UnitOfWorkFactory extends fflib_Application.UnitOfWorkFactory {
    public UnitOfWorkFactory() {
      super(
        new List<SObjectType>{
          Account.SObjectType,
          hfs_Order__c.SObjectType
          // ...list in dependency/commit order
        }
      );
    }
  }

  public class SelectorFactory extends fflib_Application.SelectorFactory {
    public SelectorFactory() {
      super(
        new Map<SObjectType, Type>{
          hfs_Order__c.SObjectType => hfs_OrderSelector.class
        }
      );
    }
  }

  public class ServiceFactory extends fflib_Application.ServiceFactory {
    public ServiceFactory() {
      super(
        new Map<Type, Type>{
          hfs_IOrderService.class => hfs_OrderServiceImpl.class
        }
      );
    }
  }

  public class DomainFactory extends fflib_Application.DomainFactory {
    public DomainFactory() {
      super(
        hfs_Application.Selector,
        new Map<SObjectType, Type>{
          hfs_Order__c.SObjectType => hfs_OrderDomain.Constructor.class
        }
      );
    }
  }
}
```

**Each factory owns its own map, inside its own no-arg constructor** — the top-level "instances" section stays short and scannable; the actual SObjectType/Type wiring for a given layer lives with that layer's own factory subclass, not mixed together in one place. This is purely organizational — `hfs_Application.Selector.newInstance(...)` and friends work identically to before.

(The fflib factory `setMock(...)` methods are protected `@TestVisible`, so each factory subclass also gets a public `override setMock(...)` that just calls `super.setMock(...)` — omitted above for brevity; see `force-app/hfs-backend/main/default/classes/hfs_Application.cls` for the exact shape. Call `super.setMock(...)` rather than poking any inherited protected field directly — the field names are an fflib implementation detail that can change between versions.)

**Rule:** no class outside `hfs_Application.cls` should ever call `new hfs_OrderServiceImpl()`, `new hfs_OrderSelector()`, or the Domain constructor directly — and outside the Service's own three-class trio (Section 6), nothing should call `hfs_Application.Service.newInstance(...)` directly either. Always go through `hfs_OrderService` (the Service facade), `hfs_OrdersSelector.newInstance()`, `hfs_OrdersDomain.newInstance(...)`. This is the single change that makes everything downstream mockable.

---

## 3. Naming Conventions — Master Reference

**Every Apex and LWC file in this project carries the `hfs_` prefix.** For LWC bundles specifically: the platform requires component names to start with a lowercase letter, contain only alphanumeric/underscore characters, and never end with — or double up — an underscore. `hfs_shopifyOrderCard` satisfies all of that (starts with `h`, single non-trailing underscore).

| Artifact                                                                              | Convention                                                                                                                                                                                                          | Example                                                         |
| ------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------- |
| Selector class                                                                        | `hfs_[SingularObject]Selector`                                                                                                                                                                                      | `hfs_OrderSelector`                                             |
| Selector interface                                                                    | `hfs_I[SingularObject]Selector`                                                                                                                                                                                     | `hfs_IOrderSelector`                                            |
| Domain class                                                                          | `hfs_[SingularObject]Domain`                                                                                                                                                                                        | `hfs_OrderDomain`                                               |
| Domain interface                                                                      | `hfs_I[SingularObject]Domain`                                                                                                                                                                                       | `hfs_IOrderDomain`                                              |
| Service interface                                                                     | `hfs_I[UseCase]Service`                                                                                                                                                                                             | `hfs_IOrderService`                                             |
| Service implementation                                                                | `hfs_[UseCase]ServiceImpl`                                                                                                                                                                                          | `hfs_OrderServiceImpl`                                          |
| Service facade (what Controllers actually call)                                       | `hfs_[UseCase]Service` — plain name, no `I`, no `Impl`                                                                                                                                                              | `hfs_OrderService`                                              |
| Apex Controller (LWC-facing)                                                          | `hfs_[Feature]Controller`                                                                                                                                                                                           | `hfs_OrderController`                                           |
| Shared Controller response wrapper                                                    | `hfs_Response` (one, project-wide)                                                                                                                                                                                  | `hfs_Response.success(payload)`                                 |
| Shared exception base                                                                 | `hfs_ApplicationException` (one, project-wide)                                                                                                                                                                      | `hfs_OrderValidationException extends hfs_ApplicationException` |
| Error code constants (centralized, grouped by comment banner per domain — Section 11) | `hfs_Constants` (one, project-wide)                                                                                                                                                                                 | `hfs_Constants.ORDER_ALREADY_SUBMITTED`                         |
| Error message Custom Label (paired to a code)                                         | `hfs_Error_[PascalCaseOfCode]`                                                                                                                                                                                      | `hfs_Error_Order_Already_Submitted`                             |
| Technical/guard-clause error codes (developer-facing, no Label)                       | same `hfs_Constants` catalog as business codes                                                                                                                                                                      | `hfs_Constants.EMPTY_PAYLOAD`                                   |
| Input-validation guard utility                                                        | `hfs_Guard` (one, project-wide)                                                                                                                                                                                     | `hfs_Guard.notNull(orderId, 'orderId')`                         |
| Wrapper (Controller ↔ LWC payloads)                                                   | `hfs_[Feature]Wrapper`                                                                                                                                                                                              | `hfs_OrderSummaryWrapper`                                       |
| External-system client/gateway (callouts)                                             | `hfs_[System][Noun]Client`                                                                                                                                                                                          | `hfs_ExternalSystemClient`                                      |
| Trigger                                                                               | `hfs_[Object]Trigger` — singular, exactly one per object                                                                                                                                                            | `hfs_OrderTrigger`                                              |
| Trigger handler                                                                       | `hfs_[Object]TriggerHandler`                                                                                                                                                                                        | `hfs_OrderTriggerHandler`                                       |
| Batch Apex                                                                            | `hfs_[Feature]Batch`                                                                                                                                                                                                | `hfs_OrderCleanupBatch`                                         |
| Queueable                                                                             | `hfs_[Feature]Queueable`                                                                                                                                                                                            | `hfs_OrderSyncQueueable`                                        |
| Schedulable                                                                           | `hfs_[Feature]Scheduler`                                                                                                                                                                                            | `hfs_NightlySyncScheduler`                                      |
| Test class                                                                            | `hfs_[ClassName]Test`                                                                                                                                                                                               | `hfs_OrderServiceImplTest`                                      |
| Test data factory                                                                     | `hfs_TestDataFactory` (one shared utility)                                                                                                                                                                          | `hfs_TestDataFactory.createOrders(5)`                           |
| Selector/Domain factory shortcut                                                      | `public static hfs_I[SingularObject][Selector\|Domain] newInstance(...)` on the concrete class — wraps `hfs_Application.X.newInstance(...)` + the cast                                                              | `hfs_OrderSelector.newInstance()`                               |
| Service facade's private resolver                                                     | `private static hfs_I[UseCase]Service service()` on the facade class — wraps `hfs_Application.Service.newInstance(...)` + the cast; every public facade method is a one-line passthrough to `service().method(...)` | `service().getOrderSummaries(accountId)`                        |
| Apex method (generic query)                                                           | `get[SingularObject]Records(whereClause, fieldsToAdd, bindMap)`                                                                                                                                                     | `getOrderRecords(...)`                                          |
| Apex method (generic write)                                                           | `create[SingularObject]Records` / `update[SingularObject]Records`                                                                                                                                                   | `createOrderRecords`, `updateOrderRecords`                      |
| Variables — collections                                                               | plural, purpose-revealing                                                                                                                                                                                           | `ordersToUpdate`, `accountIdToOrdersMap`                        |
| Constants                                                                             | `UPPER_SNAKE_CASE`                                                                                                                                                                                                  | `MAX_BATCH_SIZE`                                                |
| Custom object / field API name                                                        | `hfs_[ObjectName]__c` / `hfs_[Field_Name]__c` — extends to everything newly developed (objects, fields, record types, permission sets, and other new metadata), not retroactive to anything already built           | `hfs_Order__c`, `hfs_Total_Amount__c`                           |
| LWC bundle (folder + JS)                                                              | `hfs_[camelCaseName]`                                                                                                                                                                                               | `hfs_shopifyOrderStatusCard`                                    |
| LWC in markup                                                                         | kebab-case of the same name, underscore preserved                                                                                                                                                                   | `<c-hfs_shopify-order-status-card>`                             |
| LWC Jest test                                                                         | `[componentName].test.js` in `__tests__`                                                                                                                                                                            | `hfs_shopifyOrderStatusCard.test.js`                            |
| Shared LWC utility module (cross-component)                                           | `hfs_[purpose]Utils` — one focused module per functional area, not one project-wide catch-all                                                                                                                       | `hfs_dateUtils`, `hfs_cacheUtils`                               |
| Per-component labels/constants file                                                   | `hfs_shopifyOrderCardUtils.js` — colocated inside its own bundle, not separately prefixed                                                                                                                           | `lwc/hfs_shopifyOrderCard/hfs_shopifyOrderCardUtils.js`         |

---

## 4. Selector Layer

Query methods are **generic**, not one bespoke `selectBy...` method per use case. The Service layer builds the `whereClause` and bind variables for whatever it needs; the Selector just knows how to run them safely.

**Every Selector implements its own interface** (`hfs_I[SingularObject]Selector`), and the concrete
class exposes a static `newInstance()` that wraps `hfs_Application.Selector.newInstance(...)` +
the cast — callers stop repeating that boilerplate at every call site, and mocking targets the
interface rather than a concrete class.

```apex
public interface hfs_IOrdersSelector {
  List<hfs_Order__c> getOrderRecords(
    String whereClause,
    List<String> fieldsToAdd,
    Map<String, Object> bindMap
  );
}
```

```apex
public inherited sharing class hfs_OrderSelector extends fflib_SObjectSelector implements hfs_IOrdersSelector {
  /**
   * @description Resolves this Selector through hfs_Application so it stays mockable.
   * @return the registered hfs_IOrdersSelector implementation
   */
  public static hfs_IOrdersSelector newInstance() {
    return (hfs_IOrdersSelector) hfs_Application.Selector.newInstance(
      hfs_Order__c.SObjectType
    );
  }

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
  public List<hfs_Order__c> getOrderRecords(
    String whereClause,
    List<String> fieldsToAdd,
    Map<String, Object> bindMap
  ) {
    // newQueryFactory() seeds the query from getSObjectFieldList() above — the default
    // field list lives there, not duplicated as a second literal set here.
    fflib_QueryFactory qf = newQueryFactory();
    if (fieldsToAdd != null) {
      for (String fieldName : fieldsToAdd) {
        qf.selectField(fieldName); // additive only — never replaces the default fields
      }
    }
    if (String.isNotBlank(whereClause)) {
      qf.setCondition(whereClause);
    }

    Map<String, Object> binds = (bindMap != null)
      ? bindMap
      : new Map<String, Object>();
    return (List<hfs_Order__c>) Database.queryWithBinds(
      qf.toSOQL(),
      binds,
      AccessLevel.USER_MODE
    );
  }
}
```

Called from a Service method like this:

```apex
hfs_IOrdersSelector ordersSelector = hfs_OrderSelector.newInstance();
Map<String, Object> binds = new Map<String, Object>{ 'accountId' => accountId };
List<hfs_Order__c> orders = ordersSelector.getOrderRecords(
    'AccountId__c = :accountId',
    new List<String>{ 'CreatedDate' },
    binds
);
```

Rules:

- **One Selector per SObject**, with one generic query method plus whatever the base `fflib_SObjectSelector` gives you for free (e.g. `selectSObjectsById` for straight Id lookups — no need to reinvent that one).
- **One interface per Selector, plus a static `newInstance()` on the concrete class** — resolve through `hfs_OrderSelector.newInstance()` rather than repeating `(hfs_OrderSelector) hfs_Application.Selector.newInstance(hfs_Order__c.SObjectType)` at every call site.
- `Database.queryWithBinds(..., AccessLevel.USER_MODE)` is the mechanism that makes a fully generic `whereClause` string safe — it takes bind variables as a `Map<String, Object>` rather than string concatenation, and `USER_MODE` keeps FLS/CRUD enforcement as the default.
- **`fieldsToAdd` is additive only** — the default field list lives in `getSObjectFieldList()` (the standard fflib seam every Selector already implements), not a second hardcoded list duplicated inside the query method. `newQueryFactory()` seeds the query from it automatically; `fieldsToAdd` is appended on top via `qf.selectField(...)`, never a replacement. This guarantees fields the Selector itself relies on internally are always present regardless of caller input, at the cost of a caller never being able to trim the default set down. See `hfs_ContactsSelector.selectByEmail(...)` for the same `newQueryFactory()`/`setCondition()` style already in use, and Section 14.8 for a full worked example.
- **Real tradeoff worth naming:** a generic method loses the self-documenting, one-query-per-method structure that makes it easy to see everywhere a given field is queried. If `fieldsToAdd` is ever built from anything outside the Service layer's own control, validate it against a known field allow-list before it reaches the query string.

---

## 5. Domain Layer

Domain classes expose **generic create/update methods** driven by field-value maps. (`fflib_SObjectDomain` also gives you the standard trigger-lifecycle overrides — `onBeforeInsert`, `onValidate`, etc. — but those only run when a Domain is resolved during a real Trigger's DML via `fflib_SObjectDomain.triggerHandler(...)`, Section 8. No object in this codebase has a Trigger yet — Section 17 — so they're omitted from the sample below to keep it focused on the create/update pattern this section is actually about.)

**Every Domain implements its own interface** (`hfs_I[SingularObject]Domain`), same as Selector,
and the concrete class exposes static `newInstance(...)` overloads — one from records already in
hand, one from a bare `Set<Id>` when the caller only has Ids.

```apex
public interface hfs_IOrderDomain {
  void updateOrderRecords(
    List<hfs_Order__c> records,
    fflib_ISObjectUnitOfWork uow
  );
}
```

```apex
public inherited sharing class hfs_OrderDomain extends fflib_SObjectDomain implements hfs_IOrderDomain {
  public hfs_OrderDomain(List<hfs_Order__c> records) {
    super(records);
  }

  public class Constructor implements fflib_SObjectDomain.IConstructable {
    public fflib_SObjectDomain construct(List<SObject> sObjectList) {
      return new hfs_OrderDomain((List<hfs_Order__c>) sObjectList);
    }
  }

  /**
   * @description Resolves this Domain over already-fetched records through hfs_Application
   * so it stays mockable.
   * @param records the Orders to wrap
   * @return the registered hfs_IOrderDomain implementation
   */
  public static hfs_IOrderDomain newInstance(List<hfs_Order__c> records) {
    return (hfs_IOrderDomain) hfs_Application.Domain.newInstance(records);
  }

  /**
   * @description Resolves this Domain by Id — looks the records up via the Selector first,
   * since a Domain always wraps real records, never bare Ids.
   * @param recordIds the Order Ids to wrap
   * @return the registered hfs_IOrderDomain implementation
   */
  public static hfs_IOrderDomain newInstance(Set<Id> recordIds) {
    return newInstance(
      hfs_OrderSelector.newInstance()
        .getOrderRecords(
          'Id IN :recordIds',
          null,
          new Map<String, Object>{ 'recordIds' => recordIds }
        )
    );
  }

  public static void createOrderRecords(
    List<hfs_Order__c> records,
    fflib_ISObjectUnitOfWork uow
  ) {
    uow.registerNew(records);
  }

  public void updateOrderRecords(
    List<hfs_Order__c> records,
    fflib_ISObjectUnitOfWork uow
  ) {
    uow.registerDirty(records);
  }
}
```

Rules:

- **One interface per Domain, plus static `newInstance(...)` overloads on the concrete class** — resolve through `hfs_OrderDomain.newInstance(orders)` (or `newInstance(orderIds)`) rather than repeating `(hfs_OrderDomain) hfs_Application.Domain.newInstance(orders)` at every call site.
- **Never persists.** `createOrderRecords`/`updateOrderRecords` register against a passed-in `fflib_ISObjectUnitOfWork`; they never call `commitWork()`.
- **Typed records, not field-value maps.** `create[Objects]Records`/`update[Objects]Records` take a `List<{ObjectApi}>` of records the caller already built/mutated — not a `Map<String, Object>` field-value map. This is simpler and compile-safe (a typo in a field name is caught at build time, not at runtime), at the cost of not supporting a genuinely dynamic/unknown-field-shape update (e.g. from a deserialized, schema-less JSON payload) — if that use case shows up for real, it's worth a dedicated method rather than reintroducing field maps as the default. See Section 14.8 for a worked example.

---

## 6. Service Layer

**Three classes per Service, not two** — an interface, an implementation, and a thin static
facade that's the only one anything outside this section ever calls.

```apex
public interface hfs_IOrderService {
  List<hfs_Order__c> getOrderSummaries(Id accountId);
  void submitOrder(Id orderId);
}
```

```apex
public inherited sharing class hfs_OrderServiceImpl implements hfs_IOrderService {
  public List<hfs_Order__c> getOrderSummaries(Id accountId) {
    hfs_IOrdersSelector selector = hfs_OrderSelector.newInstance();
    return selector.getOrderRecords(
      'AccountId__c = :accountId',
      new List<String>{ 'External_Reference_Id__c' },
      new Map<String, Object>{ 'accountId' => accountId }
    );
  }

  public void submitOrder(Id orderId) {
    fflib_ISObjectUnitOfWork uow = hfs_Application.UnitOfWork.newInstance();

    hfs_IOrdersSelector selector = hfs_OrderSelector.newInstance();
    List<hfs_Order__c> orders = selector.getOrderRecords(
      'Id = :orderId',
      null,
      new Map<String, Object>{ 'orderId' => orderId }
    );
    orders[0].Status__c = 'Submitted';

    hfs_IOrderDomain orderDomain = hfs_OrderDomain.newInstance(orders);
    orderDomain.updateOrderRecords(orders, uow);

    uow.commitWork();
  }
}
```

```apex
/**
 * @description Static facade — the only door anything outside this file calls. Every public
 * method is a one-line passthrough to the mockable instance resolved via service().
 */
public with sharing class hfs_OrderService {
  @TestVisible
  private static hfs_IOrderService service() {
    return (hfs_IOrderService) hfs_Application.Service.newInstance(
      hfs_IOrderService.class
    );
  }

  public static List<hfs_Order__c> getOrderSummaries(Id accountId) {
    return service().getOrderSummaries(accountId);
  }

  public static void submitOrder(Id orderId) {
    service().submitOrder(orderId);
  }
}
```

Rules:

- **Interface, Impl, and a static Facade — three classes, always.** `hfs_IOrderService` (interface, `I`-prefixed) declares the use cases; `hfs_OrderServiceImpl` implements them with real instance methods; `hfs_OrderService` (plain name, no `I`, no `Impl`) is the static facade every external caller actually uses. Nothing outside this trio ever calls `hfs_Application.Service.newInstance(...)` directly, and nothing outside this trio ever holds an `hfs_IOrderService`-typed reference.
- **The facade's `service()` resolver is `private` (`@TestVisible` only so a test can reach it if it ever genuinely needs to)** — every one of its public methods is a one-line passthrough (`return service().theMethod(...)`, or `service().theMethod(...)` for `void`). It never contains real logic itself.
- A Service method is a **use case**, not a CRUD wrapper.
- Service methods own the **transaction boundary**: one `commitWork()` per use case.
- **External-system callouts don't live in the Service class itself** — a dedicated client class (`hfs_ExternalSystemClient`) handles callout mechanics.
- **Services throw real, typed exceptions** (`hfs_OrderValidationException`, etc.) rather than knowing anything about `hfs_Response` — that wrapper is a Controller-boundary concept only (Section 10). A Service only catches when it's translating a lower-level exception into a domain-meaningful one (Section 11.1); otherwise it lets exceptions propagate. Keeping Services exception-based, not response-wrapper-based, is what lets a Queueable, Batch, or another Service call `hfs_OrderService` (the facade) without dragging an LWC-shaped response object into a non-UI context.

---

## 7. Unit of Work

- **A Domain method never creates its own Unit of Work and never commits — it only registers against whatever `fflib_ISObjectUnitOfWork` instance the caller (always a Service method) hands it as a parameter.** See Section 14.8 for a worked example of this split.
- Obtain it via `hfs_Application.UnitOfWork.newInstance()` — never `new fflib_SObjectUnitOfWork(...)` directly outside `hfs_Application.cls`.
- `registerNew` / `registerDirty` / `registerDeleted` / `registerRelationship` / `registerUpsert` can be called from Domain _or_ Service methods.
- **Only the outermost Service method calls `commitWork()`.**
- Prefer the USER_MODE-aware DML path over the legacy `SimpleDML`.
- There's no per-object "Unit of Work class" to scaffold — `hfs_Application.UnitOfWork` is the single, project-wide factory registered once in Section 2.

---

## 8. Triggers

```apex
trigger hfs_OrderTrigger on hfs_Order__c(
  before insert,
  before update,
  before delete,
  after insert,
  after update,
  after delete,
  after undelete
) {
  hfs_OrderTriggerHandler.run();
}
```

```apex
public inherited sharing class hfs_OrderTriggerHandler {
  public static Boolean bypass = false;

  public static void run() {
    if (bypass) {
      return;
    }
    fflib_SObjectDomain.triggerHandler(hfs_OrderDomain.class);
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
      List<hfs_Order__c> orders = hfs_OrderService.getOrderSummaries(accountId);
      return hfs_Response.success(hfs_OrderSummaryWrapper.fromList(orders));
    } catch (Exception e) {
      return hfs_Response.error(e);
    }
  }

  @AuraEnabled
  public static hfs_Response submitOrder(Id orderId) {
    try {
      hfs_OrderService.submitOrder(orderId);
      return hfs_Response.success(null);
    } catch (Exception e) {
      return hfs_Response.error(e);
    }
  }
}
```

Rules:

- **A Controller only ever calls a Service's static facade — never a Selector or Domain directly, not even for a pure read, and never the Impl or `hfs_Application.Service.newInstance(...)` either.** The facade is the one door in; it calls the Impl, which calls the Selector. This holds with no exceptions: a Controller validates arguments (`hfs_Guard`), calls exactly one facade method (e.g. `hfs_OrderService.getOrderSummaries(...)`), and returns `hfs_Response` — that's the whole job.
- Controllers are **thin**: call one Service facade method, wrap the result in `hfs_Response.success(...)`, wrap any exception in `hfs_Response.error(e)`.
- `@AuraEnabled(cacheable=true)` for reads only; plain `@AuraEnabled` for actions.
- Declare Controllers `with sharing` explicitly.
- The `payload` inside `hfs_Response.success(...)` is a wrapper (`hfs_OrderSummaryWrapper`), never a raw SObject.
- LWC components never call the Selector or Service layer directly — the Controller is the only door.

---

## 10. The `hfs_Response` Wrapper

Every `@AuraEnabled` method across every Controller returns the same shape, so every LWC component handles success/failure the same way instead of each one inventing its own return contract.

**Structure adopted from a comparable project's `sf_ucs_Response`** (field shape and constructor
intent, not its CMDT-driven code/message lookup or dynamically-constructed Label name — see
Section 17 for why that part isn't adopted). `status` is a String rendered from a nested enum
rather than a `Boolean isSuccess`, matching `sf_ucs_Response.status`/`ResponseStatuses` — the
real tradeoff is that LWC-side checks become a string comparison (`data.status === 'SUCCESS'`)
instead of a clean boolean read; accepted here for consistency with the reference structure.

```apex
public with sharing class hfs_Response {
  @AuraEnabled
  public String status;
  @AuraEnabled
  public String statusCode;
  @AuraEnabled
  public String message;
  @AuraEnabled
  public String uiMessage;
  @AuraEnabled
  public Object payload;

  public enum ResponseStatuses {
    SUCCESS,
    ERROR
  }

  private hfs_Response() {
  }

  public static hfs_Response success(Object payload) {
    hfs_Response response = new hfs_Response();
    response.status = String.valueOf(ResponseStatuses.SUCCESS);
    response.payload = payload;
    return response;
  }

  public static hfs_Response error(String message, String statusCode) {
    return error(message, statusCode, message);
  }

  /**
   * @param message developer-facing detail — not guaranteed safe to display as-is
   * @param statusCode machine-readable code from hfs_Constants
   * @param uiMessage the safe, user-facing text — a Custom Label value at the throw site
   */
  public static hfs_Response error(
    String message,
    String statusCode,
    String uiMessage
  ) {
    hfs_Response response = new hfs_Response();
    response.status = String.valueOf(ResponseStatuses.ERROR);
    response.message = message;
    response.statusCode = statusCode;
    response.uiMessage = uiMessage;
    return response;
  }

  /**
   * Safe default for a caught Exception. hfs_ApplicationException — built via
   * hfs_ApplicationException.build(message, errorCode), or a typed subclass —
   * was written deliberately for the end user to see, so its message and
   * errorCode (Section 11) pass straight through as both message and uiMessage
   * (the two are the same value today since hfs_ApplicationException only carries
   * one string — see Section 17's open item on a genuine dual-message design).
   * Anything else (NullPointerException, DmlException, LimitException, etc.) is
   * unexpected/system-level — logged via Nebula Logger (Section 11.2) once
   * installed (currently plain System.debug — see Section 11.2's open item),
   * sanitized to a generic message and code before it reaches the client.
   */
  public static hfs_Response error(Exception e) {
    if (e instanceof hfs_ApplicationException) {
      hfs_ApplicationException appEx = (hfs_ApplicationException) e;
      return error(appEx.getMessage(), appEx.errorCode, appEx.getMessage());
    }
    Logger.error('Unexpected exception caught in hfs_Response.error', e);
    Logger.saveLog();
    String safeMessage = 'Something went wrong. Please try again or contact support.';
    return error(safeMessage, hfs_Constants.UNEXPECTED_ERROR, safeMessage);
  }
}
```

Rules:

- **Fields:** `status` (String — `'SUCCESS'`/`'ERROR'`, rendered from the nested `ResponseStatuses` enum), `statusCode` (machine-readable — lets an LWC branch on e.g. `hfs_Constants.VALIDATION` without string-matching a message; see Section 11 for where codes and messages actually come from), `message` (developer-facing detail, not guaranteed safe to display), `uiMessage` (the safe, user-facing text — what the LWC actually shows), `payload` (`Object` — whatever wrapper/list the method returns on success).
- **`ResponseStatuses` is nested inside `hfs_Response` itself**, not a separate `hfs_ResponseConstants` class the way `sf_ucs_Response`/`sf_ucs_ResponseConstants` split it — HFS isn't adopting the CMDT-backed status-code catalog that class otherwise exists for (that job already belongs to `hfs_Constants`), so a second file just for one enum isn't worth it.
- **This avoids a real Apex/LWC gotcha on purpose:** an uncaught exception thrown from an `@AuraEnabled` method gets auto-wrapped by the platform into a generic `AuraHandledException` whose message is stripped on the client _unless_ the developer explicitly calls `.setMessage(...)` before throwing. `hfs_Response` sidesteps this entirely — real error detail travels inside the JSON payload, never through the exception mechanism, so nobody has to remember the `.setMessage()` step.
- **Message-safety split:** custom exceptions extend a shared `hfs_ApplicationException` base rather than `Exception` directly. This is what lets `hfs_Response.error(Exception e)` tell "a business exception someone deliberately wrote a safe message and code for" apart from "an unexpected system-level exception whose real message might leak implementation detail."
- **Boundary rule:** `hfs_Response` lives at the Controller layer only. Selector/Domain/Service classes never construct or return one — they throw typed exceptions like any other Apex code, and it's the Controller's job to catch those and translate them (Section 9). This keeps the Service/Domain/Selector layers usable from non-UI callers (Batch, Queueable, another Service) that shouldn't have to know an LWC-shaped wrapper exists.
- **No `@wire`, by design (full detail in Section 12.1):** because the Controller catches its own exceptions, a cacheable wired method would almost always resolve into the wire's `data` branch even on a business-level failure — the wire's built-in `error` branch would stop being the error-handling mechanism, a real divergence from how `@wire` is documented to work. Rather than have every component author independently discover that `data.status` is what actually matters, LWCs call every Apex method imperatively instead (reads included) — one calling convention, no `data`/`error` split to reason about.

---

## 11. General Apex Coding Standards

- **Sharing:** default new classes to `inherited sharing`. Reserve explicit `with sharing` for entry points (Controllers, top-of-transaction Queueables/Batch) and `without sharing` only with a one-line comment stating why.
- **Bulkification:** no SOQL or DML inside a `for` loop, ever.
- **Exceptions, error codes, and messages.** All custom exceptions extend `hfs_ApplicationException`, which carries an `errorCode` set at construction — this is what makes `hfs_Response.error(Exception e)` (Section 10) able to tell a deliberate, safe-to-show business exception apart from an unexpected one, and what lets the `errorCode` flow through to `hfs_Response.statusCode` automatically.

  ```apex
  public virtual class hfs_ApplicationException extends Exception {
    public String errorCode { get; private set; }

    public hfs_ApplicationException(String errorCode, String message) {
      this(message);
      this.errorCode = errorCode;
    }

    public void setErrorCode(String code) {
      this.errorCode = code;
    }

    /** Reads message-first at call sites that prefer that order (e.g. guard clauses). */
    public static hfs_ApplicationException build(String message, String code) {
      return new hfs_ApplicationException(code, message);
    }
  }
  ```

  Most real throw sites construct `hfs_ApplicationException` directly via the `build(message, code)` factory rather than defining a subclass per error:

  ```apex
  throw hfs_ApplicationException.build(
      System.Label.hfs_Error_Order_Already_Submitted,
      hfs_Constants.ORDER_ALREADY_SUBMITTED
  );
  ```

  A dedicated typed subclass is still the right call when a `catch` block genuinely needs to distinguish this error from every other business exception — `hfs_AccountValidationException` in Section 14.8 is a worked example:

  ```apex
  public class hfs_OrderValidationException extends hfs_ApplicationException {
    public hfs_OrderValidationException(String errorCode, String message) {
      super(errorCode, message);
    }
  }
  ```

  **Error codes** are compile-time-safe Apex constants — not Custom Metadata, not raw string literals at the throw site. This project centralizes every error code (shared, per-domain, and technical/guard-clause) in one `hfs_Constants` class, grouped by comment banner per domain:

  ```apex
  public class hfs_Constants {
    // Shared / cross-domain
    public static final String UNEXPECTED_ERROR = 'UNEXPECTED_ERROR';

    // Order domain
    public static final String ORDER_ALREADY_SUBMITTED = 'ORDER_ALREADY_SUBMITTED';
    public static final String ORDER_HAS_UNRESOLVED_ITEMS = 'ORDER_HAS_UNRESOLVED_ITEMS';

    // Technical / guard-clause (developer-facing)
    public static final String EMPTY_PAYLOAD = 'HFS_TECH_001';
    public static final String NULL_ARGUMENT = 'HFS_TECH_002';
    public static final String MALFORMED_INPUT = 'HFS_TECH_003';
  }
  ```

  A single, centralized `hfs_Constants` is the accepted convention **for now**, at this project's current scale — not a permanent rejection of splitting per-domain; see the concrete revisit trigger in Section 17.

  **Messages are Custom Labels**, not a hardcoded map and not Custom Metadata — this reuses the exact mechanism Section 12.2 already establishes for LWC-facing text, so it isn't a second parallel system. A Label reference (`System.Label.hfs_Error_X`) is checked at deploy time — reference one that doesn't exist and the deploy fails, which a Metadata-Type DeveloperName lookup wouldn't catch until runtime — and it comes with Translation Workbench support for free if that's ever needed. Name the Label after the code it pairs with: `hfs_Error_<PascalCaseOfCode>`.

  For messages that need dynamic content, Custom Labels support `{0}`/`{1}` placeholders with `String.format`:

  ```apex
  String message = String.format(
      System.Label.hfs_Error_Order_Has_Unresolved_Items,
      new List<String>{ order.Name, String.valueOf(unresolvedCount) }
  );
  throw hfs_ApplicationException.build(message, hfs_Constants.ORDER_HAS_UNRESOLVED_ITEMS);
  ```

  **Why not Custom Metadata for this:** CMDT's real advantages — translatable-ish structured records, edits without a full deploy — don't actually apply here. Everything ships through the same GitHub Actions pipeline regardless of metadata type, so CMDT isn't any faster to change than a Label or an Apex constant, and CMDT has no built-in translation support the way Labels do. It would become the right tool the moment an error needs more than a message — e.g. an external integration wanting to know whether a given failure is retryable, its backoff policy, or an HTTP-status equivalent — because that's a genuinely structured, multi-field record CMDT is built for and a Label can't represent. Worth revisiting then, not before.

  Throw specific exceptions, catch narrowly, never swallow silently.

- **Technical / guard-clause errors** — empty payload, null argument, malformed input — are identical in nature no matter which Controller hits them, never worded for an end user, and not worth a Custom Label since there's nothing to translate. They live in the same `hfs_Constants` catalog as business codes above, in their own comment-banner section, rather than a separate class.

  **`hfs_Guard`** turns the common checks into one call instead of every Controller hand-writing its own null/empty check with its own slightly different wording. It takes the developer-facing **field name** being checked (used to build the message), not a caller-supplied error code — each check method hardcodes which `hfs_Constants` code it throws:

  ```apex
  public class hfs_Guard {
    public static void notNull(Object value, String fieldName) {
      if (value == null) {
        throw hfs_ApplicationException.build(
          'Argument [' + fieldName + '] must not be null.',
          hfs_Constants.NULL_ARGUMENT
        );
      }
    }

    public static void notBlank(String value, String fieldName) {
      if (String.isBlank(value)) {
        throw hfs_ApplicationException.build(
          'Argument [' + fieldName + '] must not be blank.',
          hfs_Constants.EMPTY_PAYLOAD
        );
      }
    }

    public static void notEmpty(List<SObject> values, String fieldName) {
      if (values == null || values.isEmpty()) {
        throw hfs_ApplicationException.build(
          'No records found for [' + fieldName + '].',
          hfs_Constants.NO_RECORDS_FOUND
        );
      }
    }

    public static Id validId(String value, String fieldName) {
      notNull(value, fieldName);
      try {
        return Id.valueOf(value);
      } catch (System.StringException e) {
        throw hfs_ApplicationException.build(
          'Argument [' + fieldName + '] is not a valid Id.',
          hfs_Constants.MALFORMED_INPUT
        );
      }
    }
  }
  ```

  **`validId` is for a raw `String` that needs to become an `Id`** — e.g. a wrapper field deserialized from JSON — not for an `@AuraEnabled` method parameter already typed `Id`. The platform coerces (and rejects a malformed) `Id`-typed parameter before the method body ever runs, so this check doesn't apply there; it earns its keep specifically where `Id.valueOf(...)` would otherwise leak a raw `System.StringException` instead of a clean `hfs_Response` error.

  **`notEmpty` takes `List<SObject>`, not `List<Object>`.** Apex generics are invariant — a `List<Account>` or `List<hfs_Order__c>` returned from a Selector is not assignable to a `List<Object>` parameter, so that signature (an earlier version of this doc's own mistake) doesn't actually compile against a real query result. `List<SObject>` is the correct, idiomatic type here, and every Selector result is already an `SObject` list.

  **Shared "no records found" pattern.** `hfs_Constants.NO_RECORDS_FOUND` is one project-wide, domain-neutral code for "a lookup came back empty" — reusable by any Service, not re-derived per feature. It comes with two message flavors, chosen by which call site you use:
  - **`hfs_Guard.notEmpty(records, 'fieldName')`** — the default. Throws with a plain, hardcoded, developer-facing message (no Custom Label, nothing to translate) — same technical/guard-clause tier as `notNull`/`notBlank` above. Use this when the caller doesn't need the end user to see specific wording.
  - **`hfs_ApplicationException.build(System.Label.hfs_Error_No_Records_Found, hfs_Constants.NO_RECORDS_FOUND)`**, thrown directly (bypassing `hfs_Guard`) — the polished, translatable, user-facing message, for when the "not found" condition is something the end user should actually understand (e.g. a UI-driven lookup/rename flow). Same shared code either way, so an LWC can still branch on `statusCode` consistently regardless of which message flavor a given throw site used.

  See Section 14.8 for a worked example of the user-facing path.

  **Real tradeoff worth naming:** this is simpler to call than a design where the caller also picks the error code, but it does give something up — every `notNull` check anywhere in the app throws the exact same `NULL_ARGUMENT` code no matter how specific the caller might want to be; only the field name in the message varies. Reasonable at this project's current scale; revisit if a real case ever needs a more specific code from the same kind of check.

  Used at the top of a Controller method, before any real logic runs:

  ```apex
  @AuraEnabled
  public static hfs_Response submitOrder(Id orderId) {
      try {
          hfs_Guard.notNull(orderId, 'orderId');
          // ...real logic
          return hfs_Response.success(null);
      } catch (Exception e) {
          return hfs_Response.error(e);
      }
  }
  ```

  Most useful at the Controller boundary (that's where unvalidated client input first enters Apex), but `hfs_Guard` isn't Controller-only — any Service method can use it for the same kind of defensive check. Add new checks to `hfs_Guard` and new codes to `hfs_Constants` as real repeated patterns show up; don't pre-build every conceivable guard up front.

  **`hfs_Constants.VALIDATION` is the generic "business rule failed, no dedicated code yet" fallback** — the same role `NO_RECORDS_FOUND` plays for empty lookups and `UNEXPECTED_ERROR` plays for system failures. A Service throws it directly (not through `hfs_Guard`, which is the technical/guard-clause tier only) when a business rule is violated and it isn't yet common enough to warrant its own code/Label:

  ```apex
  throw hfs_ApplicationException.build(
      System.Label.hfs_Error_Validation,
      hfs_Constants.VALIDATION
  );
  ```

  Once that rule comes up often enough to matter (worth a specific user-facing message, or worth an LWC branching on it specifically), graduate it to a dedicated code + Label the same way `DUPLICATE_EMAIL`/`ORDER_ALREADY_SUBMITTED` already are — `VALIDATION` is a starting point, not a permanent home for every business rule.

  **Decision table — when do I throw, and with what?**

  | Situation                                                                    | Mechanism                                                                                                                                 | Code                   |
  | ---------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------- | ---------------------- |
  | Required argument is null                                                    | `hfs_Guard.notNull(value, 'fieldName')`                                                                                                   | `NULL_ARGUMENT`        |
  | Required string is blank                                                     | `hfs_Guard.notBlank(value, 'fieldName')`                                                                                                  | `EMPTY_PAYLOAD`        |
  | A string that should be an Id is malformed                                   | `hfs_Guard.validId(value, 'fieldName')`                                                                                                   | `MALFORMED_INPUT`      |
  | A Selector/lookup returned zero rows, dev-facing is fine                     | `hfs_Guard.notEmpty(records, 'fieldName')`                                                                                                | `NO_RECORDS_FOUND`     |
  | Same, but the end user needs to see it                                       | `hfs_ApplicationException.build(System.Label.hfs_Error_No_Records_Found, hfs_Constants.NO_RECORDS_FOUND)`                                 | `NO_RECORDS_FOUND`     |
  | A business rule is violated, no dedicated code yet                           | `hfs_ApplicationException.build(System.Label.hfs_Error_Validation, hfs_Constants.VALIDATION)`                                             | `VALIDATION`           |
  | A business rule is violated and is common/important enough to name           | Add a dedicated code + paired Label (+ a typed subclass if a `catch` needs to distinguish it)                                             | e.g. `DUPLICATE_EMAIL` |
  | A record-level constraint during trigger-context DML                         | Domain's `onValidate()` + `addError()` — **never** an exception (Section 5, Section 11.1)                                                 | n/a                    |
  | An unexpected/system-level failure (NPE, DmlException, LimitException, etc.) | Don't catch narrowly — let it propagate to the Controller, which maps it automatically via `hfs_Response.error(Exception e)` (Section 10) | `UNEXPECTED_ERROR`     |

  **Fail-fast, one error at a time, is deliberate — not a gap.** `hfs_Guard` checks throw immediately on the first problem; there is no mechanism for accumulating and returning several field-level errors from one Apex call, and none is planned. That's because the LWC layer owns full-form validation (required fields, email format, etc.) via native component validity (`reportValidity()`) and/or its own JS checks _before_ Apex is ever invoked — see `hfs_selfRegistration.js`/`hfs_registrationForm.js` for the existing pattern. Apex-side guards exist to catch a bypassed or buggy client call (e.g. a direct imperative Apex invocation, a client-side validation bug), not to replace that client-side validation. If a real case ever needs Apex to be the source of truth for multi-field validation, that's worth a deliberate redesign of `hfs_Response`'s shape (Section 10) — not something to bolt onto `hfs_Guard`'s fail-fast checks.

### 11.1 Where try/catch Belongs

Section 9/10 nailed this down for Controllers. The rest of the codebase needs the same clarity, especially the layers that don't have a Controller sitting downstream to catch for them.

| Layer                                             | Catches?                                                                                                                                                                                                                                                                    | Why                                                                                                                                                                              |
| ------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Selector                                          | No                                                                                                                                                                                                                                                                          | A query failure is systemic — there's nothing selector-level to recover from.                                                                                                    |
| Domain                                            | No — validation uses `addError()`, not exceptions (Section 5). **Only fires inside a real Trigger context** (`fflib_SObjectDomain.triggerHandler(...)` wired to an object Trigger, Section 8) — calling `registerNew`/`registerDirty` alone does not invoke `onValidate()`. | Different mechanism entirely; not an error path.                                                                                                                                 |
| Service                                           | Only to **translate** a low-level/technical exception into a domain-meaningful `hfs_ApplicationException`. Otherwise let it propagate.                                                                                                                                      | Keeps the caller — Controller, Queueable, another Service — dealing with one typed, catchable exception instead of guessing what a dependency might throw.                       |
| External client (e.g. `hfs_ExternalSystemClient`) | Yes — catches transport-level exceptions (`CalloutException`, timeouts) and rethrows a typed one                                                                                                                                                                            | So every caller gets a consistent exception type regardless of which raw failure the HTTP layer produced.                                                                        |
| Controller                                        | Always — the terminal catch, converts anything into `hfs_Response` (Section 10)                                                                                                                                                                                             | It's the boundary to the LWC; there's nowhere else for an error to go.                                                                                                           |
| Queueable / Batch / Scheduled                     | Always — their **own** top-level try/catch                                                                                                                                                                                                                                  | There is no Controller downstream. An uncaught exception here just triggers Salesforce's default Apex Exception Email and the failure is otherwise invisible to the application. |

**The external client is where technical and business errors actually meet.** A callout timeout is a technical detail; "we couldn't sync this record with the external system, try again shortly" is what the person who triggered the action needs to know. The client catches the low-level failure and re-throws a business exception (Label-backed message, per Section 11) — it doesn't let the raw `CalloutException` propagate up to the Controller, where it would just fall into `hfs_Response.error(Exception e)`'s generic "unexpected error" branch and lose the useful context:

```apex
public class hfs_ExternalIntegrationException extends hfs_ApplicationException {
  public hfs_ExternalIntegrationException(String errorCode, String message) {
    super(errorCode, message);
  }
}
```

```apex
// SYNC_FAILED lives in hfs_Constants alongside every other error code (Section 11) —
// no separate hfs_IntegrationErrorCodes class.
public inherited sharing class hfs_ExternalSystemClient {
  public HttpResponse syncRecord(hfs_Order__c order) {
    try {
      return new Http().send(buildRequest(order));
    } catch (CalloutException e) {
      throw new hfs_ExternalIntegrationException(
        hfs_Constants.SYNC_FAILED,
        System.Label.hfs_Error_Integration_Sync_Failed
      );
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
      hfs_OrderService.syncOrders(orderIds);
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

**Don't wrap it in an `hfs_` facade.** Every other cross-cutting piece in this doc (`hfs_Response`, `hfs_Guard`) got a thin project wrapper because it's _our_ logic with room to evolve. Nebula Logger's own API is already clean, and it's stable, permissively-licensed, external vendor code — wrapping it just adds a layer with nothing to say. Call `Logger.*` directly.

**Per-environment log level control** comes from `LoggerSettings__c`, a custom hierarchy setting (org → profile → user) that ships with the package — worth knowing about since it's a concrete example of the right tool for "runtime-configurable, non-translatable settings," distinct from both the Custom Labels (Section 11) and the Custom Metadata question (Section 11) already discussed.

**Worth a look once this is in place, not required now:** Nebula Logger has a Slack notification plugin (unlocked-package-only) that can post to a channel on ERROR-level logs — a natural extension of the Slack alerting already built in Section 13 of the CI/CD strategy doc, using infrastructure that already exists.

- **No hardcoded Ids** (Record Type, Profile, User) — resolve via `Schema.SObjectType....getRecordTypeInfosByDeveloperName()`, Custom Metadata, or Custom Labels.
- **Config, not constants-in-code**, for anything that legitimately differs across Dev/QA/UAT/Production.
- **ApexDoc-style comments** on every public class and public method.
- Formatting matches whatever the PMD ruleset enforces on PR (Section 15).

---

## 12. LWC Component Standards

- **Composability — dumb components, smart containers.**
- **Every Apex call — reads and writes — is imperative, via `async`/`await`. No `@wire`.** See Section 12.1 for the reasoning and the pattern.
- **Business logic stays in Apex.**
- **Use base Lightning components** (`lightning-*`) before hand-rolling equivalents.
- **Performance:** avoid unbounded `@track`ing of large objects, debounce input-driven Apex calls, lazy-load heavy child components.

### 12.1 Consuming `hfs_Response`

**No `@wire` — every Apex call, read or write, is imperative, using `async`/`await` (never
`.then()`/`.catch()` chaining).** Two reasons: it keeps one calling convention for every Apex
interaction instead of two (reads via wire, writes imperative), and it sidesteps a real
`@wire`/`hfs_Response` impedance mismatch entirely — because the Controller catches its own
exceptions, a cacheable wired method almost always resolves into the wire's `data` branch even on
a business-level failure, so `@wire`'s built-in `error` branch stops being the error-handling
mechanism and every component author has to independently discover that `data.status` is what
actually matters. Going all-imperative means there's no wire `data`/`error` split to reason about
at all — just a Promise you `await` and a response you check.

Every Apex call returns `hfs_Response`. Check `status === 'SUCCESS'` before touching `payload`;
never assume success just because the `await` didn't throw.

```javascript
// Write (e.g. a button-triggered action)
async handleSubmit() {
    try {
        const response = await submitOrder({ orderId: this.orderId });
        if (response.status === 'SUCCESS') {
            this.dispatchEvent(new ShowToastEvent({
                title: 'Success',
                message: this.labels.orderSubmitted,
                variant: 'success'
            }));
        } else {
            this.dispatchEvent(new ShowToastEvent({
                title: 'Error',
                message: response.uiMessage,
                variant: 'error'
            }));
        }
    } catch (error) {
        // Defensive backstop only — shouldn't normally fire, since the
        // Controller catches its own exceptions and always resolves
        // with an hfs_Response instead of throwing.
        this.dispatchEvent(new ShowToastEvent({
            title: 'Unexpected Error',
            message: reduceErrors(error),
            variant: 'error'
        }));
    }
}
```

```javascript
// Read (e.g. loading data on component init) — same shape as a write, just called from
// connectedCallback() instead of a click handler.
async connectedCallback() {
    try {
        const response = await getOrderSummaries({ accountId: this.recordId });
        if (response.status === 'SUCCESS') {
            this.orders = response.payload;
        } else {
            this.errorMessage = response.uiMessage; // a business-level error, not a transport failure
        }
    } catch (error) {
        // Defensive backstop only — see the write example above.
        this.errorMessage = reduceErrors(error);
    }
}
```

### 12.2 Labels, Constants, and Shared Utilities

**Per-component `{componentName}Utils.js`.** Every component bundle gets its own colocated
`{componentName}Utils.js` (named after the component itself, not a generic `utils.js`) holding
that component's Custom Label imports and any local constants. The main component `.js` file
imports from it rather than importing labels/constants directly:

```
lwc/hfs_shopifyOrderCard/
    hfs_shopifyOrderCard.html
    hfs_shopifyOrderCard.js
    hfs_shopifyOrderCard.css
    hfs_shopifyOrderCard.js-meta.xml
    hfs_shopifyOrderCardUtils.js   ← labels + constants for this component only
```

```javascript
// hfs_shopifyOrderCardUtils.js
import ORDER_SUBMITTED_LABEL from "@salesforce/label/c.hfs_Order_Submitted_Message";
import ORDER_FAILED_LABEL from "@salesforce/label/c.hfs_Order_Failed_Message";

export const labels = {
  orderSubmitted: ORDER_SUBMITTED_LABEL,
  orderFailed: ORDER_FAILED_LABEL
};

export const MAX_VISIBLE_ROWS = 10;
```

```javascript
// hfs_shopifyOrderCard.js
import { LightningElement } from "lwc";
import { labels, MAX_VISIBLE_ROWS } from "./hfs_shopifyOrderCardUtils";

export default class Hfs_shopifyOrderCard extends LightningElement {
  labels = labels;
  maxRows = MAX_VISIBLE_ROWS;
}
```

**Relative imports (`./hfs_shopifyOrderCardUtils`) only work within the same bundle folder** — this pattern is for a component's own private labels/constants, not for sharing code across components.

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
import { formatShortDate } from "c/hfs_dateUtils";
import { reduceErrors } from "c/hfs_errorUtils";
```

**Rule of thumb:** if two or more components need the same logic, it goes in the shared module for that functional area — start a new focused module if nothing existing fits; don't fold unrelated logic into an existing one just because it's already there. If it's specific to one component's labels or magic numbers, it stays local in that component's own `{componentName}Utils.js` (unchanged — see above).

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

    User restrictedUser = hfs_TestDataFactory.createUserWithPermissionSet(
      'HFS_Order_Submitter'
    );

    Test.startTest();
    System.runAs(restrictedUser) {
      hfs_OrderService.submitOrder(orders[0].Id);
    }
    Test.stopTest();

    hfs_Order__c result = [
      SELECT Status__c
      FROM hfs_Order__c
      WHERE Id = :orders[0].Id
    ];
    System.Assert.areEqual(
      'Submitted',
      result.Status__c,
      'Order should be submitted by a user with the right permission set.'
    );
  }

  @isTest
  static void submitOrder_orderAlreadySubmitted_throwsValidationException() {
    fflib_ApexMocks mocks = new fflib_ApexMocks();
    hfs_OrderSelector selectorMock = (hfs_OrderSelector) mocks.mock(
      hfs_OrderSelector.class
    );
    fflib_ISObjectUnitOfWork uowMock = (fflib_ISObjectUnitOfWork) mocks.mock(
      fflib_SObjectUnitOfWork.class
    );

    hfs_Order__c alreadySubmitted = new hfs_Order__c(
      Id = fflib_IDGenerator.generate(hfs_Order__c.SObjectType),
      Status__c = 'Submitted'
    );

    mocks.startStubbing();
    mocks.when(
        selectorMock.getOrderRecords(
          (String) fflib_Match.anyObject(),
          (Map<String, Object>) fflib_Match.anyObject(),
          (List<String>) fflib_Match.anyObject()
        )
      )
      .thenReturn(new List<hfs_Order__c>{ alreadySubmitted });
    mocks.stopStubbing();

    hfs_Application.Selector.setMock(selectorMock);
    hfs_Application.UnitOfWork.setMock(uowMock);

    try {
      hfs_OrderService.submitOrder(alreadySubmitted.Id);
      System.Assert.fail('Expected hfs_OrderValidationException.');
    } catch (hfs_OrderValidationException e) {
      System.Assert.isTrue(
        e.getMessage().contains('already submitted'),
        'Exception message should explain why.'
      );
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
- **Controller tests assert directly on `hfs_Response`** — `System.Assert.areEqual('SUCCESS', response.status, ...)` / `System.Assert.areEqual('Submitted', ((hfs_OrderSummaryWrapper) response.payload).status, ...)` for the success path (the second `.status` here is the wrapper's own business field, unrelated to `hfs_Response.status`), and `System.Assert.areEqual('ERROR', response.status, ...)` plus a check on `uiMessage`/`statusCode` for the failure path — same two-tier structure as any other class.
- Coverage: 75% is the CI gate floor, not the target.

### 13.1 Mocking Reference by Layer

| Dependency   | Mock it with                                                           | Register it with                                                                                                                                         |
| ------------ | ---------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Selector     | `(hfs_OrderSelector) mocks.mock(hfs_OrderSelector.class)`              | `hfs_Application.Selector.setMock(selectorMock)`                                                                                                         |
| Domain       | `(hfs_OrderDomain) mocks.mock(hfs_OrderDomain.class)`                  | `hfs_Application.Domain.setMock(domainMock)`                                                                                                             |
| Service      | `(hfs_IOrderService) mocks.mock(hfs_IOrderService.class)`              | `hfs_Application.Service.setMock(hfs_IOrderService.class, serviceMock)` — then call the facade (`hfs_OrderService.method(...)`), never the mock directly |
| Unit of Work | `(fflib_ISObjectUnitOfWork) mocks.mock(fflib_SObjectUnitOfWork.class)` | `hfs_Application.UnitOfWork.setMock(uowMock)`                                                                                                            |

Notes:

- **Domain mocking is the one you'll reach for least.** Tier 1 tests deliberately run Domain logic against real records. Double-check `hfs_Application.Domain.setMock(...)`'s exact signature against the fflib version actually installed before relying on it — unlike `Selector`/`Service`/`UnitOfWork`, `hfs_Application.cls` does not currently wrap `Domain` in a public-setMock subclass.
- Mock the Service layer when testing a Controller in isolation, or when Service A calls Service B.
- Always `mocks.startStubbing()` / `mocks.stopStubbing()` around `mocks.when(...)`, and `mocks.verify(mock, times)` when asserting an interaction happened.

---

## 14. Scaffolding Templates — New Object Checklist

Placeholders: `{Object}` = singular PascalCase name, `{Objects}` = plural, `{ObjectApi}` = full API name — remember this now includes the `hfs_` prefix for a newly created object (e.g. `hfs_Contract__c`, Section 3).

**A fully worked example of this entire pattern** — Constants, Application factory, Exception, Selector, Domain, Service, Controller, and Tier 1/Tier 2 tests — using the standard `Account` object, is in Section 14.8 below. It is illustrative only, like every other code sample in this doc — not deployed, not a production feature, no compiling `.cls` file behind it. Use it as the concrete reference alongside the templates below, especially for the additive Selector shape (Section 4), the Domain's typed register-only methods (Section 5), the Service's single `commitWork()` (Section 6), the shared `NO_RECORDS_FOUND` code plus a typed exception (Section 11), and the mocked-Unit-of-Work test pattern (Section 13).

### 14.1 Selector — _Section 4_

```apex
public interface hfs_I{Objects}Selector {
    List<{ObjectApi}> get{Objects}Records(String whereClause, List<String> fieldsToAdd, Map<String, Object> bindMap);
}
```

```apex
public inherited sharing class hfs_{Objects}Selector extends fflib_SObjectSelector implements hfs_I{Objects}Selector {

    public static hfs_I{Objects}Selector newInstance() {
        return (hfs_I{Objects}Selector) hfs_Application.Selector.newInstance({ObjectApi}.SObjectType);
    }

    public List<Schema.SObjectField> getSObjectFieldList() {
        return new List<Schema.SObjectField>{ {ObjectApi}.Id, {ObjectApi}.Name };
    }

    public Schema.SObjectType getSObjectType() {
        return {ObjectApi}.SObjectType;
    }

    public List<{ObjectApi}> get{Objects}Records(String whereClause, List<String> fieldsToAdd, Map<String, Object> bindMap) {
        fflib_QueryFactory qf = newQueryFactory();
        if (fieldsToAdd != null) {
            for (String fieldName : fieldsToAdd) {
                qf.selectField(fieldName);
            }
        }
        if (String.isNotBlank(whereClause)) {
            qf.setCondition(whereClause);
        }

        Map<String, Object> binds = (bindMap != null) ? bindMap : new Map<String, Object>();
        return (List<{ObjectApi}>) Database.queryWithBinds(qf.toSOQL(), binds, AccessLevel.USER_MODE);
    }
}
```

### 14.2 Domain — _Section 5_

```apex
public interface hfs_I{Objects}Domain {
    void update{Objects}Records(List<{ObjectApi}> records, fflib_ISObjectUnitOfWork uow);
}
```

```apex
public inherited sharing class hfs_{Objects}Domain extends fflib_SObjectDomain implements hfs_I{Objects}Domain {

    public hfs_{Objects}Domain(List<{ObjectApi}> records) {
        super(records);
    }

    public class Constructor implements fflib_SObjectDomain.IConstructable {
        public fflib_SObjectDomain construct(List<SObject> sObjectList) {
            return new hfs_{Objects}Domain((List<{ObjectApi}>) sObjectList);
        }
    }

    public static hfs_I{Objects}Domain newInstance(List<{ObjectApi}> records) {
        return (hfs_I{Objects}Domain) hfs_Application.Domain.newInstance(records);
    }

    public static void create{Objects}Records(List<{ObjectApi}> records, fflib_ISObjectUnitOfWork uow) {
        // see Section 5
    }

    public void update{Objects}Records(List<{ObjectApi}> records, fflib_ISObjectUnitOfWork uow) {
        // see Section 5
    }
}
```

### 14.3 Service — _Section 6_

```apex
public interface hfs_I{Object}Service {
    // Name methods for actual use cases.
}
```

```apex
public inherited sharing class hfs_{Object}ServiceImpl implements hfs_I{Object}Service {
    // One commitWork() per use case. On failure, throw an hfs_ApplicationException
    // subclass with a code from hfs_{Object}ErrorCodes and a message from a paired
    // hfs_Error_[Code] Custom Label — see Section 11.
}
```

```apex
// Static facade — the only door anything outside this file calls.
public with sharing class hfs_{Object}Service {
    @TestVisible
    private static hfs_I{Object}Service service() {
        return (hfs_I{Object}Service) hfs_Application.Service.newInstance(hfs_I{Object}Service.class);
    }

    // One public static passthrough per use case, e.g.:
    // public static void doTheThing(...) { service().doTheThing(...); }
}
```

If this object needs its own error codes, add `hfs_{Object}ErrorCodes` alongside it (Section 11) — don't add them to another domain's file or a shared catch-all.

### 14.4 Trigger + TriggerHandler — _Section 8_

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
        fflib_SObjectDomain.triggerHandler(hfs_{Objects}Domain.class);
    }
}
```

### 14.5 Controller — _Sections 9 & 10_ (only if the LWC layer needs it)

```apex
public with sharing class hfs_{Object}Controller {

    @AuraEnabled(cacheable=true)
    public static hfs_Response get{Objects}Summaries(/* params */) {
        try {
            // hfs_Guard.notNull(...) / .notBlank(...) for basic input checks first
            // hfs_{Object}Service facade (never the Impl, never Selector/Domain directly) → Wrapper → hfs_Response.success(...)
        } catch (Exception e) {
            return hfs_Response.error(e);
        }
    }
}
```

### 14.6 Register with `hfs_Application.cls` — _Section 2_

Add one entry to the map inside the matching nested Factory's own constructor (each factory
owns its own map — see Section 2):

```apex
{ObjectApi}.SObjectType                                          // inside UnitOfWorkFactory()'s list
{ObjectApi}.SObjectType => hfs_{Objects}Selector.class            // inside SelectorFactory()'s map
{ObjectApi}.SObjectType => hfs_{Objects}Domain.Constructor.class   // inside DomainFactory()'s map
hfs_I{Object}Service.class => hfs_{Object}ServiceImpl.class       // inside ServiceFactory()'s map
```

### 14.7 Tests — _Section 13_

- `hfs_{Objects}SelectorTest`
- `hfs_{Objects}DomainTest` (Domain — real records, no mocks)
- `hfs_{Object}ServiceImplTest` — Tier 1 + Tier 2, calling through the `hfs_{Object}Service` facade (not `new`-ing the Impl, not calling the Impl's methods directly) — the facade has no test class of its own since it's a trivial passthrough, exercised implicitly here
- `hfs_{Object}ControllerTest` (if a Controller was added) — assert on `hfs_Response.status`/`payload`/`uiMessage`
- Add a `create{Objects}(Integer count)` method to `hfs_TestDataFactory`

### 14.8 Full Worked Example — Account

Everything above is a template with placeholders. This section is the same pattern applied
concretely, end to end, against the standard `Account` object — Constants, Application factory,
Exception, Selector, Domain, Service, Controller, and Tier 1/Tier 2 tests. **It's illustrative
only, like every other code block in this doc — it is not deployed, not a production feature,
and there's no compiling `.cls` file behind it anywhere in the repo.** Read it alongside the
section it demonstrates: the additive Selector shape (Section 4), the Domain's typed register-only
methods (Section 5), the Service's single `commitWork()` (Section 6), the shared
`hfs_Constants.NO_RECORDS_FOUND` pattern plus a typed exception subclass (Section 11), and the
Tier 1/Tier 2 test structure including mocking the Unit of Work (Section 13).

**Constants** — one reference-only code (`NAME_TOO_LONG`) alongside the pattern's own naming
convention. Note what's deliberately _not_ here: the "Account not found" case uses the real,
project-wide `hfs_Constants.NO_RECORDS_FOUND` directly (Section 11) — not everything in a feature
needs its own local code; a genuinely shared one gets reused as-is.

```apex
public class hfs_AccountConstants {
  public static final String NAME_TOO_LONG = 'ACCOUNT_NAME_TOO_LONG';
}
```

**Application factory** — same shape as the real `hfs_Application.cls` (Section 2): each nested
Factory subclass owns its own map inside its own no-arg constructor, and the public `setMock`
wrappers exist because fflib's own factory `setMock(...)` methods are protected `@TestVisible`.

```apex
public class hfs_AccountApplication {
  public static final UnitOfWorkFactory UnitOfWork = new UnitOfWorkFactory();
  public static final SelectorFactory Selector = new SelectorFactory();
  public static final ServiceFactory Service = new ServiceFactory();
  public static final DomainFactory Domain = new DomainFactory();

  public class UnitOfWorkFactory extends fflib_Application.UnitOfWorkFactory {
    public UnitOfWorkFactory() {
      super(new List<Schema.SObjectType>{ Account.SObjectType });
    }

    @TestVisible
    public override void setMock(fflib_ISObjectUnitOfWork mockUow) {
      super.setMock(mockUow);
    }
  }

  public class SelectorFactory extends fflib_Application.SelectorFactory {
    public SelectorFactory() {
      super(
        new Map<SObjectType, Type>{
          Account.SObjectType => hfs_AccountSelector.class
        }
      );
    }

    @TestVisible
    public override void setMock(
      SObjectType sObjectType,
      fflib_ISObjectSelector selectorInstance
    ) {
      super.setMock(sObjectType, selectorInstance);
    }
  }

  public class ServiceFactory extends fflib_Application.ServiceFactory {
    public ServiceFactory() {
      super(
        new Map<Type, Type>{
          hfs_IAccountService.class => hfs_AccountServiceImpl.class
        }
      );
    }

    @TestVisible
    public override void setMock(
      Type serviceInterfaceType,
      Object serviceImpl
    ) {
      super.setMock(serviceInterfaceType, serviceImpl);
    }
  }

  public class DomainFactory extends fflib_Application.DomainFactory {
    public DomainFactory() {
      super(
        hfs_AccountApplication.Selector,
        new Map<Schema.SObjectType, Type>{
          Account.SObjectType => hfs_AccountDomain.Constructor.class
        }
      );
    }
  }
}
```

**Exception** — a typed `hfs_ApplicationException` subclass (Section 11), used only when a
`catch` block genuinely needs to distinguish this error from every other business exception.

```apex
public class hfs_AccountValidationException extends hfs_ApplicationException {
  public hfs_AccountValidationException(String errorCode, String message) {
    super(errorCode, message);
  }
}
```

**Selector** — the additive `fieldsToAdd` shape (Section 4): the default field list lives in
`getSObjectFieldList()`, and `newQueryFactory()` picks it up automatically, matching
`hfs_ContactsSelector.selectByEmail(...)`'s own `newQueryFactory()`/`setCondition()` style. Also
shows the interface + static `newInstance()` pattern.

```apex
public interface hfs_IAccountSelector {
  List<Account> getAccountRecords(
    String whereClause,
    List<String> fieldsToAdd,
    Map<String, Object> bindParams
  );
}
```

```apex
public inherited sharing class hfs_AccountSelector extends fflib_SObjectSelector implements hfs_IAccountSelector {
  public static hfs_IAccountSelector newInstance() {
    return (hfs_IAccountSelector) hfs_AccountApplication.Selector.newInstance(
      Account.SObjectType
    );
  }

  public Schema.SObjectType getSObjectType() {
    return Account.SObjectType;
  }

  public List<Schema.SObjectField> getSObjectFieldList() {
    return new List<Schema.SObjectField>{ Account.Id, Account.Name };
  }

  public List<Account> getAccountRecords(
    String whereClause,
    List<String> fieldsToAdd,
    Map<String, Object> bindParams
  ) {
    fflib_QueryFactory qf = newQueryFactory();
    if (fieldsToAdd != null) {
      for (String fieldName : fieldsToAdd) {
        qf.selectField(fieldName);
      }
    }
    if (String.isNotBlank(whereClause)) {
      qf.setCondition(whereClause);
    }

    Map<String, Object> binds = (bindParams == null)
      ? new Map<String, Object>()
      : bindParams;
    return (List<Account>) Database.queryWithBinds(
      qf.toSOQL(),
      binds,
      AccessLevel.USER_MODE
    );
  }
}
```

**Domain** — typed `List<Account>` create/update (Section 5), never commits. Also shows the
interface + static `newInstance(...)` pattern.

```apex
public interface hfs_IAccountDomain {
  void updateAccountRecords(
    List<Account> records,
    fflib_ISObjectUnitOfWork uow
  );
}
```

```apex
public inherited sharing class hfs_AccountDomain extends fflib_SObjectDomain implements hfs_IAccountDomain {
  public hfs_AccountDomain(List<Account> records) {
    super(records);
  }

  public class Constructor implements fflib_SObjectDomain.IConstructable {
    public fflib_SObjectDomain construct(List<SObject> sObjectList) {
      return new hfs_AccountDomain((List<Account>) sObjectList);
    }
  }

  public static hfs_IAccountDomain newInstance(List<Account> records) {
    return (hfs_IAccountDomain) hfs_AccountApplication.Domain.newInstance(
      records
    );
  }

  public static void createAccountRecords(
    List<Account> records,
    fflib_ISObjectUnitOfWork uow
  ) {
    uow.registerNew(records);
  }

  public void updateAccountRecords(
    List<Account> records,
    fflib_ISObjectUnitOfWork uow
  ) {
    uow.registerDirty(records);
  }
}
```

**Service** — interface, Impl, and a static facade (Section 6), one use case
(`updateAccountName`), single `commitWork()`. Note the two different "not found" flavors don't
both appear here — this Service picks the user-facing one (Section 11) since it's UI-driven.

```apex
public interface hfs_IAccountService {
  void updateAccountName(Id accountId, String newName);
}
```

```apex
public inherited sharing class hfs_AccountServiceImpl implements hfs_IAccountService {
  private static final Integer MAX_NAME_LENGTH = 255;

  public void updateAccountName(Id accountId, String newName) {
    hfs_Guard.notNull(accountId, 'accountId');
    hfs_Guard.notBlank(newName, 'newName');

    String trimmedName = newName.trim();
    if (trimmedName.length() > MAX_NAME_LENGTH) {
      throw new hfs_AccountValidationException(
        hfs_AccountConstants.NAME_TOO_LONG,
        'Account name cannot exceed ' + MAX_NAME_LENGTH + ' characters.'
      );
    }

    hfs_IAccountSelector selector = hfs_AccountSelector.newInstance();
    List<Account> accounts = selector.getAccountRecords(
      'Id = :accountId',
      null,
      new Map<String, Object>{ 'accountId' => accountId }
    );
    if (accounts.isEmpty()) {
      // The shared, project-wide code (Section 11) — reused as-is, not re-derived.
      throw hfs_ApplicationException.build(
        System.Label.hfs_Error_No_Records_Found,
        hfs_Constants.NO_RECORDS_FOUND
      );
    }

    Account accountToUpdate = accounts[0];
    accountToUpdate.Name = trimmedName;

    fflib_ISObjectUnitOfWork uow = hfs_AccountApplication.UnitOfWork.newInstance();
    hfs_IAccountDomain accountsDomain = hfs_AccountDomain.newInstance(accounts);
    accountsDomain.updateAccountRecords(
      new List<Account>{ accountToUpdate },
      uow
    );

    uow.commitWork();
  }
}
```

```apex
/**
 * @description Static facade — the only door anything outside this file calls.
 */
public with sharing class hfs_AccountService {
  @TestVisible
  private static hfs_IAccountService service() {
    return (hfs_IAccountService) hfs_AccountApplication.Service.newInstance(
      hfs_IAccountService.class
    );
  }

  public static void updateAccountName(Id accountId, String newName) {
    service().updateAccountName(accountId, newName);
  }
}
```

**Controller** — thin entry point (Section 9): one guard, one Service facade call, `hfs_Response`.

```apex
public with sharing class hfs_AccountController {
  @AuraEnabled
  public static hfs_Response updateAccountName(Id accountId, String newName) {
    try {
      hfs_Guard.notNull(accountId, 'accountId');
      hfs_AccountService.updateAccountName(accountId, newName);
      return hfs_Response.success(null);
    } catch (Exception e) {
      return hfs_Response.error(e);
    }
  }
}
```

**Tests** — Tier 1 (real DML) + Tier 2 (ApexMocks, including the Unit of Work) for the Service,
and the same two-tier structure for the Controller (Section 13). Tier 1 assumes a
`hfs_TestDataFactory.createAccounts(Integer count)` helper — add one (mirroring `createFavourites`,
`createPrograms`, etc.) the same day a real feature actually needs Account test data; it isn't
part of the shared factory today since nothing real uses it yet.

```apex
@isTest
private class hfs_AccountServiceImplTest {
  // ---------- Tier 1: real end-to-end, no mocks ----------

  @isTest
  static void updateAccountName_realAccount_updatesNameAndCommits() {
    List<Account> accounts = hfs_TestDataFactory.createAccounts(200);

    Test.startTest();
    hfs_AccountService.updateAccountName(accounts[0].Id, 'Renamed Account 0');
    Test.stopTest();

    Account result = [SELECT Name FROM Account WHERE Id = :accounts[0].Id];
    System.Assert.areEqual(
      'Renamed Account 0',
      result.Name,
      'Account name should be updated by the service.'
    );
  }

  @isTest
  static void updateAccountName_nameTooLong_throwsValidationException() {
    Account account = hfs_TestDataFactory.createAccounts(1)[0];
    String tooLong = '';
    for (Integer i = 0; i < 256; i++) {
      tooLong += 'x';
    }

    Test.startTest();
    try {
      hfs_AccountService.updateAccountName(account.Id, tooLong);
      System.Assert.fail('Expected hfs_AccountValidationException.');
    } catch (hfs_AccountValidationException e) {
      System.Assert.areEqual(
        hfs_AccountConstants.NAME_TOO_LONG,
        e.errorCode,
        'Error code should identify the too-long validation.'
      );
    }
    Test.stopTest();
  }

  // ---------- Tier 2: mocked Selector + Unit of Work ----------

  @isTest
  static void updateAccountName_validName_commitsThroughSelectorDomainAndUow() {
    fflib_ApexMocks mocks = new fflib_ApexMocks();
    hfs_AccountSelector mockSelector = (hfs_AccountSelector) mocks.mock(
      hfs_AccountSelector.class
    );
    fflib_ISObjectUnitOfWork mockUow = (fflib_ISObjectUnitOfWork) mocks.mock(
      fflib_SObjectUnitOfWork.class
    );

    Account existing = new Account(
      Id = fflib_IDGenerator.generate(Account.SObjectType),
      Name = 'Old Name'
    );

    mocks.startStubbing();
    mocks.when(mockSelector.sObjectType()).thenReturn(Account.SObjectType);
    mocks.when(
        mockSelector.getAccountRecords(
          (String) fflib_Match.anyObject(),
          (List<String>) fflib_Match.anyObject(),
          (Map<String, Object>) fflib_Match.anyObject()
        )
      )
      .thenReturn(new List<Account>{ existing });
    mocks.stopStubbing();

    hfs_AccountApplication.Selector.setMock(mockSelector);
    hfs_AccountApplication.UnitOfWork.setMock(mockUow);

    Test.startTest();
    hfs_AccountService.updateAccountName(existing.Id, 'New Name');
    Test.stopTest();

    ((fflib_ISObjectUnitOfWork) mocks.verify(mockUow, 1)).commitWork();
  }

  @isTest
  static void updateAccountName_accountNotFound_throwsAndNeverCommits() {
    fflib_ApexMocks mocks = new fflib_ApexMocks();
    hfs_AccountSelector mockSelector = (hfs_AccountSelector) mocks.mock(
      hfs_AccountSelector.class
    );
    fflib_ISObjectUnitOfWork mockUow = (fflib_ISObjectUnitOfWork) mocks.mock(
      fflib_SObjectUnitOfWork.class
    );

    mocks.startStubbing();
    mocks.when(mockSelector.sObjectType()).thenReturn(Account.SObjectType);
    mocks.when(
        mockSelector.getAccountRecords(
          (String) fflib_Match.anyObject(),
          (List<String>) fflib_Match.anyObject(),
          (Map<String, Object>) fflib_Match.anyObject()
        )
      )
      .thenReturn(new List<Account>());
    mocks.stopStubbing();

    hfs_AccountApplication.Selector.setMock(mockSelector);
    hfs_AccountApplication.UnitOfWork.setMock(mockUow);

    Test.startTest();
    try {
      hfs_AccountService.updateAccountName(
        fflib_IDGenerator.generate(Account.SObjectType),
        'New Name'
      );
      System.Assert.fail('Expected hfs_ApplicationException.');
    } catch (hfs_ApplicationException e) {
      System.Assert.areEqual(
        hfs_Constants.NO_RECORDS_FOUND,
        e.errorCode,
        'Error code should identify the shared not-found condition.'
      );
      System.Assert.areEqual(
        System.Label.hfs_Error_No_Records_Found,
        e.getMessage(),
        'Message should be the user-facing not-found Label.'
      );
    }
    Test.stopTest();

    ((fflib_ISObjectUnitOfWork) mocks.verify(mockUow, 0)).commitWork();
  }
}
```

```apex
@isTest
private class hfs_AccountControllerTest {
  // ---------- Tier 1: real end-to-end ----------

  @isTest
  static void updateAccountName_realAccount_returnsSuccess() {
    Account account = hfs_TestDataFactory.createAccounts(1)[0];

    Test.startTest();
    hfs_Response resp = hfs_AccountController.updateAccountName(
      account.Id,
      'Renamed via Controller'
    );
    Test.stopTest();

    System.Assert.areEqual('SUCCESS', resp.status, 'Update should succeed');
    Account result = [SELECT Name FROM Account WHERE Id = :account.Id];
    System.Assert.areEqual(
      'Renamed via Controller',
      result.Name,
      'Account name should be updated'
    );
  }

  // ---------- Tier 2: mocked Service (isolate the Controller) ----------

  @isTest
  static void updateAccountName_mockedService_returnsSuccess() {
    fflib_ApexMocks mocks = new fflib_ApexMocks();
    hfs_IAccountService mockService = (hfs_IAccountService) mocks.mock(
      hfs_AccountServiceImpl.class
    );
    hfs_AccountApplication.Service.setMock(
      hfs_IAccountService.class,
      mockService
    );

    Test.startTest();
    hfs_Response resp = hfs_AccountController.updateAccountName(
      fflib_IDGenerator.generate(Account.SObjectType),
      'New Name'
    );
    Test.stopTest();

    System.Assert.areEqual(
      'SUCCESS',
      resp.status,
      'Mocked service call should succeed'
    );
  }

  @isTest
  static void updateAccountName_businessException_surfacesOwnCodeAndMessage() {
    fflib_ApexMocks mocks = new fflib_ApexMocks();
    hfs_IAccountService mockService = (hfs_IAccountService) mocks.mock(
      hfs_AccountServiceImpl.class
    );
    mocks.startStubbing();
    mocks.when(
        mockService.updateAccountName(
          (Id) fflib_Match.anyObject(),
          (String) fflib_Match.anyObject()
        )
      )
      .thenThrow(
        hfs_ApplicationException.build(
          System.Label.hfs_Error_No_Records_Found,
          hfs_Constants.NO_RECORDS_FOUND
        )
      );
    mocks.stopStubbing();
    hfs_AccountApplication.Service.setMock(
      hfs_IAccountService.class,
      mockService
    );

    Test.startTest();
    hfs_Response resp = hfs_AccountController.updateAccountName(
      fflib_IDGenerator.generate(Account.SObjectType),
      'New Name'
    );
    Test.stopTest();

    System.Assert.areEqual(
      'ERROR',
      resp.status,
      'Business exception should fail the response'
    );
    System.Assert.areEqual(
      hfs_Constants.NO_RECORDS_FOUND,
      resp.statusCode,
      'Shared not-found error code should surface unchanged'
    );
    System.Assert.areEqual(
      System.Label.hfs_Error_No_Records_Found,
      resp.uiMessage,
      'User-facing not-found message should surface unchanged'
    );
  }
}
```

---

## 15. Static Analysis Tie-In

- **PMD (via Salesforce Code Analyzer / `sf code-analyzer`)** against `**/*.cls` and `**/*.trigger`, at minimum `bestpractices` and `security`.
- **ESLint** with `@salesforce/eslint-config-lwc` against `**/lwc/**/*.js`.
- Worth a lightweight custom check enforcing the `hfs_` prefix on new class/trigger/LWC names.

---

## 16. PR Definition-of-Done Checklist

- [ ] Every new SObject-specific query lives in that object's Selector, using the generic `get[Object]Records(...)` pattern.
- [ ] **Every Controller method calls a Service, and only a Service** — never a Selector or Domain directly, not even for a pure read (Section 9).
- [ ] No Domain method calls `commitWork()`; only the owning Service method does.
- [ ] Every new class is wired through `hfs_Application.cls`.
- [ ] All new files — Apex and LWC — carry the `hfs_` prefix.
- [ ] Each object's trigger delegates to its `hfs_[Object]TriggerHandler`.
- [ ] New object work followed the Section 14 checklist in full.
- [ ] **Every `@AuraEnabled` method returns `hfs_Response` and wraps its body in try/catch** — nothing propagates as a raw/unhandled exception.
- [ ] All custom exceptions extend `hfs_ApplicationException`, not `Exception` directly — construct via `hfs_ApplicationException.build(message, code)` or a typed subclass, never a bare `Exception`.
- [ ] New error codes go in `hfs_Constants` (not a raw string literal, not a new one-off catch-all file) with a paired `hfs_Error_[PascalCaseOfCode]` Custom Label where the code is user-facing — check both don't already exist for the same logical error before adding new ones.
- [ ] New Controller-boundary payload types use `hfs_[Feature]Wrapper` naming
- [ ] Generic input checks (null/blank/empty payload) use `hfs_Guard` instead of a hand-written, one-off null check — no ad hoc `if (x == null) return hfs_Response.error('...')` with bespoke wording.
- [ ] Try/catch placement follows Section 11.1 by layer — Selector/Domain don't catch, Services only catch to translate, external clients catch-and-retype, Controllers always catch, and **every Queueable/Batch/Scheduled entry point has its own top-level try/catch** (there's no Controller downstream for async work).
- [ ] Unexpected/system-level exceptions are logged via `Logger.error(...)` + `Logger.saveLog()` (Section 11.2) — not a bare `System.debug`, and not swallowed silently.
- [ ] Every Apex call from LWC is imperative (`async`/`await`) — no `@wire` — and checks `response.status === 'SUCCESS'` before touching `payload`.
- [ ] Component-specific labels/constants live in that component's own `{componentName}Utils.js`; cross-component helpers live in the right focused `hfs_[purpose]Utils` module — not duplicated, and not dumped into an unrelated existing one.
- [ ] Test class has the Tier 1 real/permission/bulk test plus Tier 2 mocked variations.
- [ ] No hardcoded Ids, no `SeeAllData=true`.
- [ ] `sf code-analyzer` / PMD and ESLint pass locally before pushing.

---

## 17. Open Items — Not Yet Decided

- **No Trigger-backed Domain validation exercised yet.** Every object in this codebase lacks a real Trigger (Section 8), so `onValidate()`/`addError()` (Section 11.1) has never actually run — it's documented but unproven in this project. Worth a real worked example the first time an object gets a Trigger, to confirm the pattern behaves as documented rather than assuming it does.
- **`hfs_Constants` centralization — revisit trigger.** Section 11 documents the current single-class error-code catalog as accepted for now, not permanent. Revisit splitting it into per-domain `hfs_[Feature]ErrorCodes` classes once `hfs_Constants` exceeds roughly 40 constants, or once 2+ developers are regularly adding codes to it in the same sprint/parallel PRs — merge-conflict friction is the real signal, not raw line count. Real-world precedent worth knowing about: a comparable project's `sf_ucs_Constants` is one ~470-line file spanning its entire org, still comment-banner-organized, never split — suggesting the 40-constant threshold above may be conservative rather than urgent.
- **`hfs_Response` doc/code drift — real class not yet migrated.** Section 10 now documents `hfs_Response` with `sf_ucs_Response`'s field structure (`status`/`statusCode`/`message`/`uiMessage`/`payload`) as the standard going forward, but this was a **doc-only** change — the real `force-app/hfs-backend/main/default/classes/wrapper/hfs_Response.cls` still has the old shape (`isSuccess`/`errorMessage`/`errorCode`), and so does every existing Controller/test that constructs or reads one (`hfs_ToolboxController`, `hfs_RegistrationController`, `hfs_TrainingController`, etc.). Migrating the real class + all consumers is a deliberate, separate piece of work — not something to do incrementally per-Controller, since a half-migrated state (some Controllers on the old shape, some on the new) would be worse than the current, consistent-but-stale state.
- **Sharing default: `inherited sharing` vs. `with sharing` more broadly.** `hfs_Constants`/`hfs_Guard` were updated to `with sharing`, matching a comparable project's convention of declaring `with sharing` even on classes with no DML/query logic — a narrower application than Section 11's current "default to `inherited sharing`, `with sharing` for entry points only" rule. Whether that broader `with sharing`-by-default convention should replace Section 11's rule project-wide (and get retrofitted onto existing classes like `hfs_ContactsSelector`, `hfs_ContactsDomain`, etc.) is an open, unscoped decision — not applied beyond these two classes yet.
- **External-system client error/retry contract.** The exception-typing half is settled (Section 11.1 — catch transport failures, rethrow a typed `hfs_ApplicationException`). What's still open: retry/backoff policy for a failed sync — does the Queueable requeue itself, how many attempts, what backoff — and whether that policy differs for a rate-limit response versus a genuine failure. Worth deciding before the first real integration client gets built.
- **Structured, multi-field error metadata.** The current design (Section 11) covers a code + a message. If any integration needs richer per-error metadata — retryable Y/N, backoff policy, an HTTP-status equivalent — that's the trigger to introduce a Custom Metadata Type for that specific case, layered on top of the existing code, not a replacement for it.
- **Nebula Logger installation across environments.** The tool decision is made (Section 11.2) — installing it isn't. Package install against Dev/QA/UAT and adding it to the scratch org dependency config are still pending action items against the CI/CD pipeline, not something settled by this doc alone.
- **Nebula Logger's Slack plugin** (Section 11.2) is a genuinely low-effort win given the Slack infrastructure already built in the CI/CD doc, but it's a separate decision from the base logging choice and hasn't been evaluated yet.
- **`hfs_Response.payload` typed as `Object`, not a pre-serialized JSON string.** This is the more ergonomic choice for LWC and is expected to serialize correctly for nested wrappers on this org's API version, but it hasn't been proven against a deeply nested or `Map`-heavy payload yet. Worth a throwaway spike before this becomes the pattern behind every one of the project's Controllers, given how central it now is.
- **No batch/partial-success shape yet.** Any bulk integration sync (some records succeed, some fail within the same call) will need one — `hfs_Response`'s binary `status` doesn't represent that. Worth designing an `hfs_BatchResponse` (or an agreed `List<hfs_Response>` convention) before that work starts, rather than retrofitting it under deadline pressure.
- **Client-side API response caching — backlog, not being built now.** Plan: identify which `@AuraEnabled` Controller methods get called most frequently across different pages/components, and cache their responses in browser local/session storage to cut down on redundant server round-trips, with the cached data encrypted. Two things worth thinking through when this is actually picked up (not solved here): (1) cache invalidation — TTL-based expiry vs. explicit invalidation when the underlying data changes, and how that interacts with the `hfs_Response` shape; (2) client-side encryption has a real ceiling — the decryption key has to be reachable by the same JS the encryption is nominally protecting data from, so this is realistically obfuscation/defense-in-depth against casual inspection of storage, not a genuine security boundary. Fine as a reason to reduce exposure, not a reason to treat otherwise-sensitive data as safe to cache client-side.
