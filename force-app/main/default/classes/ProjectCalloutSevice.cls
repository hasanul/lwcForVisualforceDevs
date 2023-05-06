public with sharing class ProjectCalloutService {
    
    @InvocableMethod
    public static void PostOpportunityToPMS(List<Id> OpptId){
        Opportunity oppty = [SELECT Id, Name, Account.Name, CloseDate, Amount FROM Opportunity WHERE Id = :OpptId[0]];
        String serviceToken = ServiceTokens__c.getValues('ProjectServiceToken').Token__c;
        
        String jsonInput = '{\n' +
            ' "opportunityId" : "'+oppty.Id+'",\n'+
            ' "opportunityName" : "'+oppty.Name+'",\n'+
            ' "accountName" : "'+oppty.Account.Name+'",\n'+
            ' "closeDate" : "'+String.ValueOf(oppty.CloseDate).mid(0,10)+'",\n'+   
            ' "amount" : "'+oppty.Amount+'"\n}';
            
        System.enqueueJob(new QueueablePMSCall(serviceToken, jsonInput, oppty.Id));
    }    
    
    class QueueablePMSCall implements System.Queueable, Database.AllowsCallouts{
        private String serviceToken;
        private String jsonInput;
        private Id OpptId;
        
        public QueueablePMSCall(String serviceToken, String jsonInput, Id OpptId){
            this.serviceToken = serviceToken;
            this.jsonInput = jsonInput;
            this.OpptId = OpptId;
        }
        
        public void execute(QueueableContext quect){
            postToPMS(serviceToken, jsonInput, OpptId);        
        }
    }
    
    @Future(callout=true)
    private static void postToPMS(String serviceToken, String jsonInput, Id opptIds){
        HTTPRequest httpReq = new HTTPRequest();
        httpReq.setEndPoint('callout:ProjectService');
        httpReq.setMethod('POST');
        httpReq.setHeader('token',serviceToken);
        httpReq.setHeader('Content-Type', 'application/json;charset=UTF-8');
        httpReq.setBody(jsonInput);
        
        HTTP http = new HTTP();
        HTTPResponse httpRes = http.send(httpReq);
        
        Opportunity oppty = new Opportunity(Id=opptIds);
        if(httpRes.getStatusCode() == 201){
            oppty.StageName = 'Submitted Project';                
            System.debug('Success: ' + httpRes.getStatus());
        }else{
            oppty.StageName = 'Resubmit Project';
            System.debug('Failure: ' + httpRes.getStatusCode() + ' ' + httpRes.getStatus());
        }
        update oppty;
    }
}