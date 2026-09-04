/**
 * @description Data transfer objects for the My Toolbox panel. Keeps raw
 * SObjects out of the Controller-to-LWC boundary. Status constants express
 * per-source availability so the panel can degrade gracefully.
 */
public with sharing class hfs_ToolboxDTO {
    // Availability of a count or list. AVAILABLE => show value (incl. 0).
    // UNAVAILABLE => show an "unavailable" indicator, never zero/foreign data.
    public static final String STATUS_AVAILABLE = 'AVAILABLE';
    public static final String STATUS_UNAVAILABLE = 'UNAVAILABLE';

    /**
     * @description One Quick Actions row.
     */
    public class QuickActionDTO {
        @AuraEnabled public String key { get; set; }
        @AuraEnabled public String label { get; set; }
        @AuraEnabled public String icon { get; set; }
        @AuraEnabled public String destinationUrl { get; set; }
        @AuraEnabled public Boolean hasCount { get; set; }
        @AuraEnabled public Integer count { get; set; }
        @AuraEnabled public String countStatus { get; set; }
    }

    /**
     * @description One My Programs row.
     */
    public class ProgramDTO {
        @AuraEnabled public String key { get; set; }
        @AuraEnabled public String label { get; set; }
        @AuraEnabled public String icon { get; set; }
        @AuraEnabled public String destinationUrl { get; set; }
    }

    /**
     * @description Wrapper for the My Programs group carrying a list status so
     * an unreachable source shows "unavailable" rather than an empty list.
     */
    public class ProgramGroupDTO {
        @AuraEnabled public String listStatus { get; set; }
        @AuraEnabled public List<ProgramDTO> programs { get; set; }

        public ProgramGroupDTO() {
            this.listStatus = STATUS_AVAILABLE;
            this.programs = new List<ProgramDTO>();
        }
    }

    /**
     * @description One Account group link.
     */
    public class AccountLinkDTO {
        @AuraEnabled public String key { get; set; }
        @AuraEnabled public String label { get; set; }
        @AuraEnabled public String icon { get; set; }
        @AuraEnabled public String destinationUrl { get; set; }
    }
}