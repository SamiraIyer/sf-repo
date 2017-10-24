@isTest
public class ParentSortingServiceTest {

	private static Date petitionDate = System.today();
	private static Investigation__c iAD {
		get {
			if(iAD == null) {
				Id recordType = utils.getRecordTypeIdMap('Investigation__c').get('AD');
				iAD = [SELECT Id, RecordTypeId, Prelim_Extension_of_days__c, AD_Investigation_Aligned_To__c, Calculated_Preliminary_Signature__c, 
							Actual_Preliminary_Signature__c, Calculated_Final_Signature__c, Calc_Amended_Prelim_Determination_Sig__c, Petition__c, 
							Prelim_Team_Meeting_Deadline__c, Calculated_Amended_Final_Signature__c, Actual_Final_Signature__c, Final_Team_Meeting_Deadline__c, 
							Est_ITC_Notification_to_DOC_of_Final_Det__c, ITC_Notification_to_DOC_of_Final_Determ__c, Calculated_Order_FR_Signature__c, 
							Calculated_ITC_Final_FR_Published__c, Estimated_Order_FR_Published__c, Calculated_Prelim_Extension_Request_File__c, 
							Calculated_Postponement_of_PrelimDeterFR__c, 
							Prelim_Issues_Due_to_DAS__c, Prelim_Concurrence_Due_to_DAS__c, Amend_Prelim_Issues_Due_to_DAS__c, Amend_Prelim_Concurrence_Due_to_DAS__c, 
							Final_Issues_Due_to_DAS__c, Final_Concurrence_Due_to_DAS__c, Amend_Final_Issues_Due_to_DAS__c, Amend_Final_Concurrence_Due_to_DAS__c, 
							Next_Major_Deadline__c, Next_Office_Deadline__c, Next_Announcement_Date__c, Next_Due_to_DAS_Deadline__c, 
							Preliminary_Announcement_Date__c, Amended_Preliminary_Announcement_Date__c, Final_Announcement_Date__c, Amended_Final_Announcement_Date__c, 
							Calculated_ITC_Prelim_Determination__c 
						FROM Investigation__c WHERE RecordTypeId =: recordType LIMIT 1];
			}
			return iAD;
		}	
	}
	private static Investigation__c iCVD {
		get {
			if(iCVD == null) {
				Id recordType = utils.getRecordTypeIdMap('Investigation__c').get('CVD');
				iCVD = [SELECT Id, RecordTypeId, Prelim_Extension_of_days__c, AD_Investigation_Aligned_To__c, Calculated_Preliminary_Signature__c, 
							Actual_Preliminary_Signature__c, Calculated_Final_Signature__c, Calc_Amended_Prelim_Determination_Sig__c, Petition__c, 
							Prelim_Team_Meeting_Deadline__c, Calculated_Amended_Final_Signature__c, Actual_Final_Signature__c, Final_Team_Meeting_Deadline__c, 
							Est_ITC_Notification_to_DOC_of_Final_Det__c, ITC_Notification_to_DOC_of_Final_Determ__c, Calculated_Order_FR_Signature__c, 
							Calculated_ITC_Final_FR_Published__c, Estimated_Order_FR_Published__c, Calculated_Prelim_Extension_Request_File__c, 
							Petition_Initiation_Signature__c, Calculated_Postponement_of_PrelimDeterFR__c, 
							Prelim_Issues_Due_to_DAS__c, Prelim_Concurrence_Due_to_DAS__c, Amend_Prelim_Issues_Due_to_DAS__c, Amend_Prelim_Concurrence_Due_to_DAS__c, 
							Final_Issues_Due_to_DAS__c, Final_Concurrence_Due_to_DAS__c, Amend_Final_Issues_Due_to_DAS__c, Amend_Final_Concurrence_Due_to_DAS__c, 
							Next_Major_Deadline__c, Next_Office_Deadline__c, Next_Announcement_Date__c, Next_Due_to_DAS_Deadline__c, 
							Preliminary_Announcement_Date__c, Amended_Preliminary_Announcement_Date__c, Final_Announcement_Date__c, Amended_Final_Announcement_Date__c, 
							Calculated_ITC_Prelim_Determination__c 
						FROM Investigation__c WHERE RecordTypeId =: recordType LIMIT 1];
			}
			return iCVD;
		}	
	}
	private static Litigation__c testRemand {
		get {
			if (testRemand == null) {
				testRemand = [SELECT Id, Petition__c, Investigation__c, Segment__c FROM Litigation__c WHERE Investigation__c =: iAD.Id LIMIT 1];
			}
			return testRemand;
		} set;
	}
	private static Related_Organization__c testRelOrg {
		get {
			if (testRelOrg == null) {
				testRelOrg = [SELECT Id, Litigation__c, Petition__c, Investigation__c, ADCVD_Case_Number__c, Country__c, Litigation__r.Petition__c, Litigation__r.Investigation__c, Litigation__r.Segment__c 
								FROM Related_Organization__c WHERE Litigation__c =: testRemand.Id LIMIT 1];
			}
			return testRelOrg;
		} set;
	}
	private static Staffing_Assignment__c testInvestigationSA {
		get {
			if (testInvestigationSA == null) {
				testInvestigationSA = [SELECT Id, Petition__c, Investigation__c, ADCVD_Order__c, Segment__c, ADCVD_Case_Number__c, Country__c
							FROM Staffing_Assignment__c WHERE Investigation__c =:iAD.Id LIMIT 1];
			}
			return testInvestigationSA;
		} set;
	}
	private static Staffing_Assignment__c testRelOrgSA {
		get {
			if (testRelOrgSA == null) {
				testRelOrgSA = [SELECT Id, Petition__c, Investigation__c, ADCVD_Order__c, Segment__c, Related_Organization__c, ADCVD_Case_Number__c, Country__c
							FROM Staffing_Assignment__c WHERE Related_Organization__c =:iAD.Id LIMIT 1];
			}
			return testRelOrgSA;
		} set;
	}

	@isTest static void getParentSObjectType() {
		Test.startTest();
		ParentSortingService pss = new ParentSortingService();
		String testString = pss.getParentSObjectType(testInvestigationSA, 'Staffing_Assignment__c');

		Test.stopTest();
		System.assertEquals('Investigation__c', testString);
	}

	@isTest static void getGrandParentSObjectType() {
		Test.startTest();
		ParentSortingService pss = new ParentSortingService();
		String testString = pss.getGrandParentSObjectType(testRelOrg, 'Litigation__c');

		Test.stopTest();
		System.assertEquals('Investigation__c', testString);
	}


	@testSetup static void dataSetup() {
		Test.startTest();
		User testUser = TestUtils.createAdminUser(true, 'myemail@email.com.testita', 1);
		Petition__c testADPetition = TestUtils.createPetition(petitionDate, 'AD ME', true);
		Petition__c testCVDPetition = TestUtils.createPetition(petitionDate, 'CVD', true);
		Investigation__c testADinvestigation = TestUtils.createInvestigation('AD', testADPetition, true);
		Investigation__c testCVDinvestigation = TestUtils.createInvestigation('CVD', testCVDPetition, true);
		Litigation__c testLitigation = TestUtils.createLitigation(testADinvestigation.Id, 'Investigation__c', petitionDate, 'Remand', true);
		Account testAccount = TestUtils.createAccount(false);
		testAccount.BillingState = '';
		insert testAccount;
		Related_Organization__c testOrg = new Related_Organization__c (
			Litigation__c = testLitigation.Id,
			Account__c = testAccount.Id);
		insert testOrg;
	}
}