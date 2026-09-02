@isTest
private class CommunitiesLandingControllerTest {
  @isTest
  static void forwardToStartPage_delegatesToNetworkCommunitiesLanding() {
    CommunitiesLandingController controller = new CommunitiesLandingController();

    Test.startTest();
    PageReference result = controller.forwardToStartPage();
    Test.stopTest();

    System.Assert.areEqual(
      Network.communitiesLanding(),
      result,
      'forwardToStartPage should return whatever Network.communitiesLanding() resolves to.'
    );
  }
}
