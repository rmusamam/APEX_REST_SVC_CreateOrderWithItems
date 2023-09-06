@RestResource(urlMapping='/createOrderWithItems')
global with sharing class SVC_CreateOrderWithItems {
	
    global class RestResponseClass {
        global Boolean success;
        global String message;
    }
    
    @HttpPost
    global static void createOrderWithItems() {
        //try {
            RestRequest request = RestContext.request;
	        String jsonResponse = request.requestBody.toString(); // JSON response string
            Map<PriceBookEntry, OrderItem> orderItemPriceBookMap = new Map<PriceBookEntry, OrderItem>();
			OrderWithItemsWrapper requestData = (OrderWithItemsWrapper)JSON.deserialize(jsonResponse, OrderWithItemsWrapper.class);
            
            List<OrderItem> newOrderItems = new List<OrderItem>();
            List<Care_Plan_Type__c> newCarePlans =new List<Care_Plan_Type__c>();
            List<String> prdSkuList  = new List<String>();
            Map<String, Product2> productSKUmap = new Map<String, Product2>();
            Map<String, String> skuContractNumberMap = new Map<String, String>();
        
            //fetching xStoreAssociation with related AccountId
            List <XStore_Association__c> xStoreAssociations = SVC_XStoreAssociationSelector.getXStoreAssociations(requestData);
        	//fetching standard pricebook
			Pricebook2 standardPriceBook= SVC_PriceBookSelector.getStandardPriceBook().get(0); 
        	
        	//preparing sku list
        	for(OrderItemInput itemInput : requestData.order.OrderItems){
                prdSkuList.add(itemInput.productid);
            }
        	//fetching products
        	List<Product2> prodList = SVC_ProductSelector.getProductsAndPricebookEnteriesBySkuId(prdSkuList);
        	Map<Id,Product2> productMap = new Map<Id, Product2>(prodList); 
        	System.debug('prodList size: '+prodList.size());
        	

        	//preparing sku-product map
            for (Product2 prod: prodList) {
                if(prod.StockKeepingUnit != null){
                	productSKUmap.put(prod.StockKeepingUnit, prod);
                }
            }
        
            // Create the Order record
             Order newOrder = createOrder(requestData,xStoreAssociations,standardPriceBook);
        	System.debug('newOrder: '+newOrder);
                        
            for (OrderItemInput itemInput : requestData.order.OrderItems) {
               	OrderItem newOrderItem = new OrderItem();     
               	newOrderItem.OrderId = newOrder.id;
                newOrderItem.External_Id__c = itemInput.External_Id;
                newOrderItem.UnitPrice = itemInput.UnitPrice;
                newOrderItem.Quantity =itemInput.Quantity;
                newOrderItem.Line_Number__c = itemInput.Line_Number;
                newOrderItem.Price__c = itemInput.Price;
                newOrderItem.productid__c = productSKUmap.get(itemInput.productid).id;
                newOrderItem.Tax__c = itemInput.Tax;
                newOrderItem.Tax_Basis__c = itemInput.Tax_Basis;
                newOrderItem.Tax_Class_Id__c = itemInput.Tax_Class_Id;
                newOrderItem.Tax_Rate__c = itemInput.Tax_Rate;
                newOrderItem.c_fromStoreId__c = itemInput.c_fromStoreId;
                newOrderItem.Status__c = itemInput.Status;
                newOrderItem.Type__c = itemInput.Types;
                newOrderItem.c_fromStoreId__c = itemInput.c_fromStoreId;
                
                
                newOrderItem.Status__c = itemInput.Status;
                newOrderItem.Product2Id = productSKUmap.get(itemInput.productid).id;
                
                orderItemPriceBookMap.put(getPriceBookEntry(itemInput, productSKUmap, standardPriceBook.Id), newOrderItem);
                skuContractNumberMap.put(itemInput.productid, itemInput.ContractNumber);         
                

            }
        
            //creating and updating the PriceBookEntries.
            upsert new List<PriceBookEntry> (orderItemPriceBookMap.keyset());


            //creating orderitems
            List<OrderItem> ordertItems =  updateOrderProducts(orderItemPriceBookMap);
            insert ordertItems;

            //creating care plans
            createCarePlan(ordertItems, skuContractNumberMap, productMap);
            
            
            boolean success = true;
            String message = 'Success';
        	RestResponse res = RestContext.response;
        	res = createResponse(success, message);
        
       /* } catch (Exception e) {
			boolean success = false;
            String message = e.getMessage();
        	RestResponse res = RestContext.response;
        	res = createResponse(success, message);        }*/
    }
	
    public static RestResponse createResponse (boolean success, String message){
        RestResponseClass response = new RestResponseClass();
        RestResponse res = RestContext.response;
        res.addHeader('Content-Type', 'application/json');
        response.success = true;
        response.message = 'Success';
        res.responseBody = Blob.valueOf(JSON.serialize(response));
        return res;
    }

    public static List<OrderItem> updateOrderProducts(Map<PriceBookEntry, OrderItem> orderItemPriceBookMap){
        Map<Id,PriceBookEntry> productIdPriceBookEntryMap = new Map<Id,PriceBookEntry>(); 
        List<OrderItem> updatedOrderItems = new List<OrderItem>();
        for (PriceBookEntry pbeL : orderItemPriceBookMap.keyset()) {
            productIdPriceBookEntryMap.put(pbeL.Product2Id, pbeL);
        }
        for(OrderItem item : orderItemPriceBookMap.values()){
            item.PriceBookEntryId = productIdPriceBookEntryMap.get(item.productid__c).Id;
            updatedOrderItems.add(item);
        } 
        return updatedOrderItems;
    }

    public static PriceBookEntry getPriceBookEntry(SVC_CreateOrderWithItems.OrderItemInput itemInput, Map<String, Product2> productSKUmap, Id spbId){

        Product2 product = productSKUmap.get(itemInput.Productid);
        if(product != null && product.PricebookEntries.size() > 0   ){
            return product.PricebookEntries.get(0);
        } else{
            PriceBookEntry pbe = new PriceBookEntry();
            pbe.Product2Id = product.id;
            pbe.UnitPrice= itemInput.UnitPrice;
            pbe.Pricebook2Id=spbId;
            return pbe;
        }

    }
	
    public static void createCarePlan(List<OrderItem> orderItems, Map<String, String> skuContractNumberMap, MaP<ID, Product2> productMap){
        List<Care_Plan_Type__c> newCarePlans =new List<Care_Plan_Type__c>();
        for (OrderItem itemInput : orderItems) {
            if (itemInput.Type__c =='Care Plan') {
                Care_Plan_Type__c newCarePlan = new Care_Plan_Type__c();
                newCarePlan.ContractNumber__c = skuContractNumberMap.get(productMap.get(itemInput.productid__c).StockKeepingUnit);
                newCarePlan.orderId__c = itemInput.OrderId;
                newCarePlan.orderitem__c = itemInput.Id;
                newCarePlan.ProductId__c = itemInput.productid__c;
                newCarePlans.add(newCarePlan);
            }
        }
        insert newCarePlans;
    }
    
     Public Static Order createOrder(OrderWithItemsWrapper requestData, List <XStore_Association__c> xStoreAssociations,Pricebook2 standardPriceBook) {
        Order newOrder = new Order(
                EffectiveDate = Date.valueOf(requestData.order.effectivedate),
                AccountId= xStoreAssociations.get(0).Contact__r.AccountId,
                currency__c = requestData.order.orderCurrency,
                External_ID__c = requestData.order.External_Id,
                order_total__c = requestData.order.order_total,
                product_sub_total__c = requestData.order.product_sub_total,
                product_total__c = requestData.order.product_total,
                status__c = requestData.order.status,
                tax_total__c = requestData.order.tax_total,
                customer_Id__c = requestData.order.customer_Id,
                tax_value__c = requestData.order.tax_value,
                Payment_Amount__c = requestData.order.Payment_Amount,
                BillingStreet = requestData.order.BillingStreet,
                BillingCity = requestData.order.BillingCity,
                BillingCountry = requestData.order.BillingCountry,
                Billing_First_Name__c = requestData.order.Billing_First_Name,
                Billing_Full_Name__c = requestData.order.Billing_Full_Name,
                Billing_Last_Name__c = requestData.order.Billing_Last_Name,
                Billing_Phone__c = requestData.order.Billing_Phone,
                BillingPostalCode = requestData.order.BillingPostalCode,
                BillingState = requestData.order.BillingState,
                Type = requestData.order.OrderType,
                Pricebook2Id = standardPriceBook.id
            );
            insert newOrder;
        return newOrder;
    }
    
    
    // Define wrapper classes for deserialization
    public class OrderItemInput {
        public String ProductCode;
        public Decimal Quantity;
        public Decimal UnitPrice;
        public Decimal Price;
        public String productid;
        public Decimal Tax;
        public Decimal Tax_Basis;
        public String Tax_class_Id;
        public Decimal Tax_Rate;
        public String c_fromStoreId;
        public String Types;
        public String ContractNumber;
        public String External_Id;
        public Integer Line_Number;
        public String Status;
    }
    
    public class OrderWrapper {
        
        public String Account;
        public Date effectivedate;
        public String orderCurrency;
        public String External_Id;
        public Decimal order_total;
        public Decimal product_sub_total;
        public Decimal product_total;
        public String status;
        public Decimal tax_total;
        public String customer_Id;
        public Decimal tax_value;
        public Decimal Payment_Amount;
        public String BillingStreet;
        public String BillingCity;
        public String BillingCountry;
        public String Billing_First_Name;
        public String Billing_Full_Name;
        public String Billing_Last_Name;
        public String Billing_Phone;
        public String BillingPostalCode;
        public String BillingState;
        public String OrderType;
        public List<OrderItemInput> OrderItems;
    }
    
    public class OrderWithItemsWrapper {
 

        public OrderWrapper order;

    }
}