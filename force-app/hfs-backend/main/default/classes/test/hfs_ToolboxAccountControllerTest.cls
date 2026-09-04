/**
 * @description Tests for hfs_ToolboxAccountController. Verifies the three Account
 * links are returned in order with icons and destinations.
 */
@isTest
private class hfs_ToolboxAccountControllerTest {

    @isTest
    static void getAccountLinks_returnsThreeOrderedLinks() {
        // Act
        Test.startTest();
        hfs_Response resp = hfs_ToolboxAccountController.getAccountLinks();
        Test.stopTest();

        // Assert
        Assert.isTrue(resp.isSuccess, 'Response should be successful');
        List<hfs_ToolboxDTO.AccountLinkDTO> links =
            (List<hfs_ToolboxDTO.AccountLinkDTO>) resp.payload;
        Assert.areEqual(3, links.size(), 'Three account links expected');
        Assert.areEqual(System.Label.hfs_Toolbox_Account_My_Profile, links[0].label,
            'My Profile should be first');
        Assert.areEqual(System.Label.hfs_Toolbox_Account_Settings, links[2].label,
            'Settings should be last');
        Assert.isNotNull(links[0].destinationUrl, 'My Profile has a destination');
        Assert.isNotNull(links[0].icon, 'My Profile has an icon');
    }
}