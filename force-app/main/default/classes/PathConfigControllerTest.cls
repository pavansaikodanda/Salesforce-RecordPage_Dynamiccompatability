@IsTest
class PathConfigControllerTest {

    static Custom_Object_Mapping__c insertMapping() {
        Custom_Object_Mapping__c mapping = new Custom_Object_Mapping__c(
            Name = 'Path Test Mapping',
            Developer_Name__c = 'Path_Test_Mapping',
            Object_API_Name__c = 'Account',
            Page_Layout_ID__c = '0AhXXXXXXXXXXX',
            Enforce_Path_Order__c = false,
            Stage_Order_Source__c = 'Custom Order'
        );
        insert mapping;
        return mapping;
    }

    static Custom_Path_Mapping__c insertStage(Id mappingId, String stageValue, Integer order) {
        Custom_Path_Mapping__c pm = new Custom_Path_Mapping__c(
            Object_Mapping__c = mappingId,
            Stage_Value__c = stageValue,
            Stage_Label__c = stageValue,
            Stage_Order__c = order,
            Is_Active__c = true
        );
        insert pm;
        return pm;
    }

    @IsTest
    static void testGetPathConfigWithData() {
        Custom_Object_Mapping__c mapping = insertMapping();
        Custom_Path_Mapping__c stage1 = insertStage(mapping.Id, 'Open', 1);
        Custom_Path_Mapping__c stage2 = insertStage(mapping.Id, 'Closed', 2);
        insert new Custom_Path_Transition__c(
            Path_Mapping__c = stage1.Id,
            From_Stage__c = 'Open',
            To_Stage__c = 'Closed',
            Is_Allowed__c = true
        );

        Test.startTest();
        FormWrappers.PathConfigWrapper result = PathConfigController.getPathConfig(mapping.Id);
        Test.stopTest();

        Assert.isFalse(result.enforceOrder);
        Assert.areEqual('Custom Order', result.stageOrderSource);
        Assert.areEqual(2, result.stages.size());
        Assert.areEqual(1, result.transitions.size());
        Assert.areEqual('Open', result.transitions[0].fromStage);
        Assert.areEqual('Closed', result.transitions[0].toStage);
        Assert.isTrue(result.transitions[0].isAllowed);
    }

    @IsTest
    static void testGetPathConfigEmpty() {
        Custom_Object_Mapping__c mapping = insertMapping();

        Test.startTest();
        FormWrappers.PathConfigWrapper result = PathConfigController.getPathConfig(mapping.Id);
        Test.stopTest();

        Assert.areEqual(0, result.stages.size());
        Assert.areEqual(0, result.transitions.size());
    }

    @IsTest
    static void testSavePathConfigInsert() {
        Custom_Object_Mapping__c mapping = insertMapping();

        Map<String, Object> config = new Map<String, Object>{
            'enforceOrder' => true,
            'stageOrderSource' => 'Custom Order',
            'stages' => new List<Object>{
                new Map<String, Object>{ 'stageValue' => 'Prospecting', 'stageLabel' => 'Prospecting', 'stageOrder' => 1 },
                new Map<String, Object>{ 'stageValue' => 'Closed Won', 'stageLabel' => 'Closed Won', 'stageOrder' => 2 }
            },
            'transitions' => new List<Object>{
                new Map<String, Object>{ 'fromStage' => 'Prospecting', 'toStage' => 'Closed Won', 'isAllowed' => true }
            }
        };

        Test.startTest();
        PathConfigController.savePathConfig(mapping.Id, JSON.serialize(config));
        Test.stopTest();

        List<Custom_Path_Mapping__c> stages = [SELECT Stage_Value__c FROM Custom_Path_Mapping__c WHERE Object_Mapping__c = :mapping.Id ORDER BY Stage_Order__c];
        Assert.areEqual(2, stages.size());
        Assert.areEqual('Prospecting', stages[0].Stage_Value__c);

        Custom_Object_Mapping__c updated = [SELECT Enforce_Path_Order__c FROM Custom_Object_Mapping__c WHERE Id = :mapping.Id];
        Assert.isTrue(updated.Enforce_Path_Order__c);

        List<Custom_Path_Transition__c> transitions = [SELECT From_Stage__c, To_Stage__c FROM Custom_Path_Transition__c WHERE Path_Mapping__c IN :new Map<Id, Custom_Path_Mapping__c>(stages).keySet()];
        Assert.areEqual(1, transitions.size());
    }

    @IsTest
    static void testSavePathConfigDeleteRemoved() {
        Custom_Object_Mapping__c mapping = insertMapping();
        Custom_Path_Mapping__c stage1 = insertStage(mapping.Id, 'Open', 1);
        insertStage(mapping.Id, 'Closed', 2);

        Map<String, Object> config = new Map<String, Object>{
            'enforceOrder' => false,
            'stageOrderSource' => 'Custom Order',
            'stages' => new List<Object>{
                new Map<String, Object>{ 'stageValue' => 'Open', 'stageLabel' => 'Open', 'stageOrder' => 1 }
            },
            'transitions' => new List<Object>()
        };

        Test.startTest();
        PathConfigController.savePathConfig(mapping.Id, JSON.serialize(config));
        Test.stopTest();

        Integer count = [SELECT COUNT() FROM Custom_Path_Mapping__c WHERE Object_Mapping__c = :mapping.Id];
        Assert.areEqual(1, count);
    }

    @IsTest
    static void testSavePathConfigUpdateExisting() {
        Custom_Object_Mapping__c mapping = insertMapping();
        insertStage(mapping.Id, 'Open', 1);

        Map<String, Object> config = new Map<String, Object>{
            'enforceOrder' => false,
            'stageOrderSource' => 'Custom Order',
            'stages' => new List<Object>{
                new Map<String, Object>{ 'stageValue' => 'Open', 'stageLabel' => 'Open Updated', 'stageOrder' => 1, 'guidanceText' => 'Some guidance' }
            },
            'transitions' => new List<Object>()
        };

        Test.startTest();
        PathConfigController.savePathConfig(mapping.Id, JSON.serialize(config));
        Test.stopTest();

        Custom_Path_Mapping__c updated = [SELECT Stage_Label__c, Guidance_Text__c FROM Custom_Path_Mapping__c WHERE Object_Mapping__c = :mapping.Id];
        Assert.areEqual('Open Updated', updated.Stage_Label__c);
        Assert.areEqual('Some guidance', updated.Guidance_Text__c);
    }
}
