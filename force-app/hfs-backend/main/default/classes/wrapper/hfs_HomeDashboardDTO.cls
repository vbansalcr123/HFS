/**
 * @description Controller-to-LWC payload for the personalised Home dashboard (HFS-32). Holds the
 * account summary line, the four summary tiles and the optional announcement banner. This is the
 * DTO wrapped inside hfs_Response.success(...) - no SObject ever leaves the controller.
 */
public class hfs_HomeDashboardDTO {
  /** Tile status: rendered with a real value. */
  public static final String STATUS_OK = 'OK';
  /** Tile status: genuine zero - shows 0 with supporting detail and stays selectable. */
  public static final String STATUS_EMPTY = 'EMPTY';
  /** Tile status: source unreachable - shows an unavailable state rather than a zero/stale value. */
  public static final String STATUS_UNAVAILABLE = 'UNAVAILABLE';

  /** Greeting name + account summary line values. Never contains another partner's data. */
  @AuraEnabled
  public AccountSummary accountSummary { get; set; }

  /** The four summary tiles, in render order. */
  @AuraEnabled
  public List<Tile> tiles { get; set; }

  /** The active, highlighted announcement, or null when none is active (banner absent). */
  @AuraEnabled
  public Announcement announcement { get; set; }

  /**
   * @description Builds an empty DTO with an initialised tiles list.
   */
  public hfs_HomeDashboardDTO() {
    this.tiles = new List<Tile>();
  }

  /**
   * @description Greeting + account-summary line values sourced from Account/User.
   */
  public class AccountSummary {
    /** First name for the personalised greeting. */
    @AuraEnabled
    public String greetingName { get; set; }
    /** Station / company name (Account.Name). */
    @AuraEnabled
    public String accountName { get; set; }
    /** Formatted billing address line. */
    @AuraEnabled
    public String addressLine { get; set; }
    /** Account number (Account.AccountNumber). */
    @AuraEnabled
    public String accountNumber { get; set; }
    /** Partner tier (Account.ChannelProgramLevelName). */
    @AuraEnabled
    public String tier { get; set; }
  }

  /**
   * @description One summary tile (Active Orders / Downloads / Training / Open Requests).
   */
  public class Tile {
    /** Stable key for the tile (e.g. activeOrders). */
    @AuraEnabled
    public String key { get; set; }
    /** Display label (from a Custom Label). */
    @AuraEnabled
    public String label { get; set; }
    /** Display value (e.g. "3" or "9 / 15 courses"). */
    @AuraEnabled
    public String value { get; set; }
    /** Supporting detail line (e.g. "2 in transit · 1 processing"). */
    @AuraEnabled
    public String supportingDetail { get; set; }
    /** OK / EMPTY / UNAVAILABLE. */
    @AuraEnabled
    public String status { get; set; }
    /** Optional progress bar percent (Training Progress only). */
    @AuraEnabled
    public Integer progressPercent { get; set; }
    /** Top-border accent colour. */
    @AuraEnabled
    public String accent { get; set; }

    /**
     * @description Builds a tile with its key, label and accent pre-set.
     * @param key stable tile key
     * @param label display label
     * @param accent top-border accent colour
     */
    public Tile(String key, String label, String accent) {
      this.key = key;
      this.label = label;
      this.accent = accent;
    }
  }

  /**
   * @description The announcement banner payload.
   */
  public class Announcement {
    /** Banner headline. */
    @AuraEnabled
    public String title { get; set; }
    /** Banner body copy. */
    @AuraEnabled
    public String message { get; set; }
    /** Call-to-action link label. */
    @AuraEnabled
    public String ctaLabel { get; set; }
    /** Call-to-action target (site-relative / allow-listed). */
    @AuraEnabled
    public String ctaUrl { get; set; }
  }
}