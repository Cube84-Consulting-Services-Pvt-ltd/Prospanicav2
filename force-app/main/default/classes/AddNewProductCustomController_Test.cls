/**
 * @description       : 
 * @author            : ChangeMeIn@UserSettingsUnder.SFDoc
 * @group             : 
 * @last modified on  : 07-22-2025
 * @last modified by  : ChangeMeIn@UserSettingsUnder.SFDoc
**/
@isTest
public class AddNewProductCustomController_Test {

    public static final String DEFAULT_PRICE_BOOK_NAME = System.today().year() + ' Price Book';
    
    @TestSetup
    static void setupTestData() {
        // Create test products
        List<Product2> products = new List<Product2>();
        for (Integer i = 1; i <= 5; i++) {
            products.add(new Product2(
                Name = 'Test Product ' + i,
                ProductCode = 'TP' + i,
                IsActive = true,
                Description = 'Test Description ' + i,
                Total_Quantity__c = 100 + i,
                On_Hold_Quantity__c = 10 + i
            ));
        }
        insert products;
        
        // Create standard pricebook
        Pricebook2 standardPricebook = new Pricebook2(
            Id = Test.getStandardPricebookId(),
            IsActive = true
        );
        update standardPricebook;
        
        // Create custom pricebook
        Pricebook2 testPricebook = new Pricebook2(
            Name = 'Test Pricebook',
            IsActive = true
        );
        insert testPricebook;
        
        // Create pricebook entries
        List<PricebookEntry> pricebookEntries = new List<PricebookEntry>();
        for (Product2 p : products) {
            pricebookEntries.add(new PricebookEntry(
                Pricebook2Id = standardPricebook.Id,
                Product2Id = p.Id,
                UnitPrice = 100 * (products.indexOf(p) + 1),
                IsActive = true
            ));
            pricebookEntries.add(new PricebookEntry(
                Pricebook2Id = testPricebook.Id,
                Product2Id = p.Id,
                UnitPrice = 100 * (products.indexOf(p) + 1),
                IsActive = true
            ));
        }
        insert pricebookEntries;
        
        // Create test opportunity
        Opportunity testOpp = new Opportunity(
            Name = 'Test Opportunity',
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(30),
            Pricebook2Id = testPricebook.Id
        );
        insert testOpp;
    }
    
    @IsTest
    static void testSearchProducts() {
        Pricebook2 testPricebook = [SELECT Id FROM Pricebook2 WHERE Name = 'Test Pricebook' LIMIT 1];
        
        Test.startTest();
        // Test with keyword that matches products
        List<Product2> products = AddNewProductCustomController.searchProducts(testPricebook.Id, 'Test Product');
        System.assertEquals(5, products.size(), 'Should return all test products');
        
        // Test with specific product name
        products = AddNewProductCustomController.searchProducts(testPricebook.Id, 'Test Product 1');
        System.assertEquals(1, products.size(), 'Should return only one product');
        System.assertEquals('Test Product 1', products[0].Name, 'Should return correct product');
        
        // Test with blank keyword
        products = AddNewProductCustomController.searchProducts(testPricebook.Id, '');
        System.assertEquals(0, products.size(), 'Should return no products for blank keyword');
        Test.stopTest();
    }
    
    @IsTest
    static void testGetInitDetails() {
        Opportunity testOpp = [SELECT Id, Pricebook2Id, Pricebook2.Name FROM Opportunity WHERE Name = 'Test Opportunity' LIMIT 1];
        
        Test.startTest();
        String result = AddNewProductCustomController.getInitDetails(testOpp.Id, 'Test Product');
        
       

        Pricebook2 stdPriceBook = new Pricebook2();
        {
            stdPriceBook.Name = DEFAULT_PRICE_BOOK_NAME;
            stdPriceBook.IsActive = true;
            
        }
        
        insert stdPriceBook;
        
        AddNewProductCustomController.OpportunityProductWrapper wrapper = 
            (AddNewProductCustomController.OpportunityProductWrapper)JSON.deserialize(
                result, 
                AddNewProductCustomController.OpportunityProductWrapper.class
            );
        
        if (stdPriceBook != null) {
            wrapper.defaultPbId = stdPriceBook.Id;
        } else {
            wrapper.defaultPbId = null;
        }

        System.assertEquals(stdPriceBook.Name,DEFAULT_PRICE_BOOK_NAME,'Pricebook name is not there');
        System.assertEquals(stdPriceBook.Id,wrapper.defaultPbId,'Pricebook Id is mismatching');
        
        System.assertEquals(testOpp.Id, wrapper.oppDetail.Id, 'Opportunity ID should match');
        System.assertEquals(testOpp.Pricebook2Id, wrapper.oppDetail.Pricebook2Id, 'Pricebook ID should match');
        System.assertEquals(5, wrapper.productList.size(), 'Should return all test products');
        
        for (AddNewProductCustomController.ProductWrapper pw : wrapper.productList) {
            System.assertNotEquals(null, pw.pricebookEntryId, 'Pricebook entry ID should not be null');
            System.assertNotEquals(null, pw.unitPrice, 'Unit price should not be null');
            System.assertEquals('/lightning/r/Product2/' + pw.productId + '/view', pw.productUrl, 'Product URL should be correct');
            System.assert(pw.name.startsWith('Test Product'), 'Product name should start with Test Product');
        }
        Test.stopTest();
    }
    
    @IsTest
    static void testSaveProducts() {
        Opportunity testOpp = [SELECT Id, Pricebook2Id FROM Opportunity WHERE Name = 'Test Opportunity' LIMIT 1];
        List<Product2> products = [SELECT Id FROM Product2 WHERE Name LIKE 'Test Product%'];

        Set<Id> productIds = new Set<Id>();

        for(Product2 p:products)
        {
            productIds.add(p.Id);


        }

    

        Map<Id, PricebookEntry> productToPBEMap = new Map<Id, PricebookEntry>();

        for (PricebookEntry pbe : [
                                    SELECT Id, UnitPrice, Product2Id
                                    FROM PricebookEntry
                                WHERE Product2Id IN :productIds AND Pricebook2Id = :testOpp.Pricebook2Id
]) {
    productToPBEMap.put(pbe.Product2Id, pbe);
}
       
       List<AddNewProductCustomController.ProductWrapper> productWrappers = new List<AddNewProductCustomController.ProductWrapper>();

for (Product2 p : products) {
    if (productToPBEMap.containsKey(p.Id)) {
        PricebookEntry pbe = productToPBEMap.get(p.Id);

        AddNewProductCustomController.ProductWrapper pw = new AddNewProductCustomController.ProductWrapper();
        pw.productId = p.Id;
        pw.pricebookEntryId = pbe.Id;
        pw.unitPrice = pbe.UnitPrice;
        pw.quantity = 5;
        pw.selectedDate = Date.today();
        pw.lineDescription = 'Test Description';
        productWrappers.add(pw);
    }
}
        
        
        String recordData = JSON.serialize(productWrappers);
        
        Test.startTest();
        String result = AddNewProductCustomController.saveProducts(recordData, testOpp.Id);
        System.assertEquals('success', result, 'Save should be successful');
        
        // Verify records were created
        List<OpportunityLineItem> lineItems = [SELECT Id FROM OpportunityLineItem WHERE OpportunityId = :testOpp.Id];
        System.assertEquals(5, lineItems.size(), 'Should have created 5 line items');
        Test.stopTest();
    }

    @isTest
    
static void updatePBIdforOpptyTest() {
    // Get standard pricebook and activate it
    Id standardPBId = Test.getStandardPricebookId();
    Pricebook2 standardPricebook = [SELECT Id, IsActive FROM Pricebook2 WHERE Id = :standardPBId];
    standardPricebook.IsActive = true;
    update standardPricebook;

    // Create test opportunity
    Opportunity opp = new Opportunity(
        Name = 'Test Opportunity',
        StageName = 'Prospecting',
        CloseDate = Date.today().addDays(30)
    );
    insert opp;

    Test.startTest();
    String result = AddNewProductCustomController.updatePBIdforOppty(opp.Id, standardPricebook.Id);
    Test.stopTest();

    // Verify returned result
    System.assertEquals('Success', result, 'Method did not return expected result');

    // Fetch updated opportunity
    Opportunity updatedOpportunity = [
        SELECT Id, Name, Pricebook2Id
        FROM Opportunity
        WHERE Id = :opp.Id
    ];

    // Assertions
    System.assertEquals('Test Opportunity', updatedOpportunity.Name, 'Opportunity Name mismatch');
    System.assertEquals(standardPricebook.Id, updatedOpportunity.Pricebook2Id, 'Pricebook2Id not updated properly');
}

   
    
    }