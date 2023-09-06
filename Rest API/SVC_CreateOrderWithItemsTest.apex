@isTest
private class SVC_CreateOrderWithItemsTest {

    @isTest
    static void testCreateOrderWithItems() {
        // Create a test Account and Contact
        Account testAccount = new Account(Name = 'Test Account');
        insert testAccount;

        Contact testContact = new Contact(AccountId = testAccount.Id, FirstName = 'John', LastName = 'Doe', Email = 'test@example.com');
        insert testContact;
		
        Id pricebookId = Test.getStandardPricebookId();
        Pricebook2 pb = new Pricebook2(Id= pricebookId, IsActive = true );
    	update pb;

        // Create a Product2 record
        Product2 testProduct = new Product2(Name = 'Test Product', StockKeepingUnit = 'SKU001');
        insert testProduct;
        

        // Create a PriceBookEntry for the product
        PriceBookEntry pbe = new PriceBookEntry(Product2Id = testProduct.Id, Pricebook2Id =pb.Id , isActive=true, UnitPrice = 100.00);      
        insert pbe;
        
        
        XStore_Association__c xStore = new XStore_Association__c(Contact__c=testContact.id, XStore_Cust_Id__c= '123');
        insert xStore;
        

        // Serialize the request into JSON	
        String jsonRequest = '{"order": {"Account": "TestAccount","effectivedate": "2023-09-05","orderCurrency": "USD","External_Id": "12345","order_total": 500.00,"product_sub_total": 400.00,"product_total": 450.00,"status": "Open","tax_total": 50.00,"customer_Id": "123","tax_value": 10.00,"Payment_Amount": 500.00,"BillingStreet": "123 Main St","BillingCity": "City","BillingCountry": "Country","Billing_First_Name": "John","Billing_Full_Name": "John Doe","Billing_Last_Name": "Doe","Billing_Phone": "123-456-7890","BillingPostalCode": "12345","BillingState": "State","OrderType": "Online","OrderItems": [{"ProductCode": "Product123","Quantity": 2,"UnitPrice": 100.00,"Price": 200.00,"productid": "SKU001","Tax": 20.00,"Tax_Basis": 180.00,"Tax_class_Id": "TaxClass123","Tax_Rate": 10.00,"c_fromStoreId": "Store123","Types": "Product","ContractNumber": "Contract123","External_Id": "Item123","Line_Number": 1,"Status": "Active"}, {"ProductCode": "Product123","Quantity": 2,"UnitPrice": 100.00,"Price": 200.00,"productid": "SKU001","Tax": 20.00,"Tax_Basis": 180.00,"Tax_class_Id": "TaxClass123","Tax_Rate": 10.00,"c_fromStoreId": "Store123","Types": "Care Plan","ContractNumber": "Contract123","External_Id": "Item123","Line_Number": 1,"Status": "Active"}]}}';

        
        // Set up the RestRequest and RestResponse objects
        RestRequest request = new RestRequest();
        RestResponse response = new RestResponse();
        request.requestBody = Blob.valueOf(jsonRequest);
        RestContext.request = request;
        RestContext.response = response;

        // Call the createOrderWithItems method
        Test.startTest();
        SVC_CreateOrderWithItems.createOrderWithItems();
        Test.stopTest();

        // Verify the response
        SVC_CreateOrderWithItems.RestResponseClass responseObj = (SVC_CreateOrderWithItems.RestResponseClass)JSON.deserialize(
        RestContext.response.responseBody.toString(), SVC_CreateOrderWithItems.RestResponseClass.class);

        // Add assertions for the response
        System.assertEquals(true, responseObj.success);
        System.assertEquals('Success', responseObj.message);

       
    }
}