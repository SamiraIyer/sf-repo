global without sharing class CP_SaveContactRequestFlowAction {
    @InvocableMethod(label='Create Contact Request' description='Creates Contact Request Record.')
    global static void createRecord(List<RequestVariables> inputs) {
        
        List<User> defaultUserList = new list<User>();
        ContactRequest newRecord = new ContactRequest();
        RequestVariables userInputs = inputs[0];
        String userType = '';
        //Get User to set from in email
        if(defaultUserList.isempty())  {
            defaultUserList = [SELECT Id from User WHERE Alias =: Label.CP_NoReply_Alias];
        }
        //Standare Fields  
        newRecord.First_Name__c = userInputs.firstName; //mapedInputs.get('FirstName');b
        newRecord.Last_Name__c = userInputs.lastName; //mapedInputs.get('LastName');
        newRecord.Email__c = userInputs.email; //mapedInputs.get('Email');
        newRecord.RequestDescription =  userInputs.message;
        if(userInputs.country != 'NONE'){
            newRecord.Country_1__c = userInputs.country; //mapedInputs.get('Country');
        }
        newRecord.RequestReason =  userInputs.requestReason; //mapedInputs.get('Reason');
        //System and static fields 
        newRecord.OwnerId = userInputs.ownerId; //mapedInputs.get('QueueId');
        newRecord.Status = 'New';
        if(userInputs.zipCode != 'NONE'){
            newRecord.US_ZIP_CODE__c = userInputs.zipCode;
        }
        //using text as boolean since value is passed from flow  
        if(userInputs.converted == 'true'){
            newRecord.WhoId = userInputs.contactId;
            userType = 'verified';
        }
        else 
            if(userInputs.leadId != 'NONE' && userInputs.contactId != 'NONE'){
                newRecord.WhoId = userInputs.leadId;
                userType = 'unverified';
            }
        else{
            userType = 'unregistered';
        }
        database.insert(newRecord);
        sendEmail(newRecord.Email__c,userType,userInputs.contactId,newRecord.Id);
    }
    
    private static void sendEmail(String toAddress,String userType,String userId,Id requestId){
        List<EmailTemplate> templatesList = [SELECT Id, Body, Subject FROM EmailTemplate WHERE DeveloperName =: 'Contact_Us_Requested'];
        //find an active admin to statisfy email requirment when user is unregistered
        Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
        mail.setTemplateId(templatesList[0].Id);
        mail.setSaveAsActivity(false);     
        if(userType == 'verified' || userType == 'unverified'){
            mail.setTargetObjectId(userId);
        }
        else{
            mail.setTargetObjectId(UserInfo.getUserId());  
        }
        mail.setSenderDisplayName('noreply@trade.gov');
        mail.setToAddresses(new list<string>{toAddress});
        Messaging.SendEmailResult[] resultMail = Messaging.sendEmail(new Messaging.SingleEmailMessage[] { mail });
    }
    
    global class RequestVariables {
        @InvocableVariable(label='First Name' required=true)
        global String firstName;
        @InvocableVariable(label='Last Name' required=true)
        global String lastName;
        @InvocableVariable(label='Email' required=true)
        global String email;
        @InvocableVariable(label='Country Name' required=false)
        global String country;
        @InvocableVariable(label='Request Reason' required=false)
        global String requestReason;
        @InvocableVariable(label='Queue Id' required=false)
        global String ownerId;
        @InvocableVariable(label='Zip Code' required=false)
        global String zipCode;
        @InvocableVariable(label='Converted' required=false)
        global String converted;
        @InvocableVariable(label='Lead Id' required=false)
        global String leadId;
        @InvocableVariable(label='Contact Id' required=false)
        global String contactId;
        @InvocableVariable(label='Message' required=false)
        global String message;
    }
}