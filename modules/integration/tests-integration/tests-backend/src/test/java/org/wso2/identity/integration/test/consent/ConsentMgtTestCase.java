/*
 * Copyright (c) 2018, WSO2 Inc. (http://www.wso2.org) All Rights Reserved.
 *
 * WSO2 Inc. licenses this file to you under the Apache License,
 * Version 2.0 (the "License"); you may not use this file except
 * in compliance with the License.
 * You may obtain a copy of the License at
 *
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing,
 * software distributed under the License is distributed on an
 * "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
 * KIND, either express or implied. See the License for the
 * specific language governing permissions and limitations
 * under the License.
 */

package org.wso2.identity.integration.test.consent;

import org.apache.http.HttpHeaders;
import org.apache.wink.client.Resource;
import org.apache.wink.client.RestClient;
import org.json.simple.JSONArray;
import org.json.simple.JSONObject;
import org.json.simple.JSONValue;
import org.testng.Assert;
import org.testng.annotations.AfterClass;
import org.testng.annotations.BeforeClass;
import org.testng.annotations.Test;
import org.wso2.identity.integration.common.utils.ISIntegrationTest;
import org.apache.wink.client.ClientResponse;

import java.util.ArrayList;
import java.util.List;

import javax.ws.rs.core.MediaType;

import static org.wso2.identity.integration.test.util.Utils.getBasicAuthHeader;

public class ConsentMgtTestCase extends ISIntegrationTest {

    public static final String CONSENT_ENDPOINT_SUFFIX = "/api/identity/consent-mgt/v1.0/consents";
    private String isServerBackendUrl;
    private String consentEndpoint;
    private Long purposeId;

    @BeforeClass(alwaysRun = true)
    public void testInit() throws Exception {

        super.init();
        isServerBackendUrl = isServer.getContextUrls().getWebAppURLHttps();
        consentEndpoint = isServerBackendUrl + CONSENT_ENDPOINT_SUFFIX;
    }

    @AfterClass(alwaysRun = true)
    public void atEnd() {

    }

    @Test(alwaysRun = true, groups = "wso2.is", description = "Add PII Category test")
    public void testAddPIICategory() {

        String name = "http://wso2.org/claims/organization";
        String description = "Organization";
        JSONObject response = addPIICategory(name, description);

        Assert.assertEquals(name, response.get("piiCategory"));
        Assert.assertEquals(description, response.get("description"));
        Assert.assertEquals(true, response.get("sensitive"));
    }

    @Test(alwaysRun = true, groups = "wso2.is", description = "Add Purpose Category test", dependsOnMethods = {"testAddPIICategory"})
    public void testAddPurposeCategory() {

        String name = "Financial";
        String description = "Financial Purpose";
        JSONObject response = addPurposeCategory(name, description);

        Assert.assertEquals(name, response.get("purposeCategory"));
        Assert.assertEquals(description, response.get("description"));
    }

    @Test(alwaysRun = true, groups = "wso2.is", description = "Add Purpose test", dependsOnMethods = {"testAddPurposeCategory"})
    public void testAddPurpose() {

        String name = "Financial 01";
        String description = "Financial Purpose 01";
        String group = "SIGNUP";
        String groupType = "SYSTEM";
        JSONObject response = addPurpose(name, description, group, groupType);
        purposeId = (Long) response.get("purposeId");

        Assert.assertEquals(response.get("purpose"), name);
        Assert.assertEquals(response.get("description"), description);
        Assert.assertEquals(response.get("group"), group);
        Assert.assertEquals(response.get("groupType"), groupType);
        Assert.assertNotNull(response.get("piiCategories"));
        Assert.assertEquals(response.get("version"), 1L);
    }

    @Test(alwaysRun = true, groups = "wso2.is", description = "Add Purpose Version test", dependsOnMethods = {"testAddPurpose"})
    public void testAddPurposeVersion() {

        String version1Req = "{\"description\": \"Initial version\"}";
        JSONObject v1Resp = addPurposeVersion(purposeId, version1Req);
        Assert.assertEquals(v1Resp.get("version"), 2L, "Version 2 should be auto-assigned");

        // Response now includes "version": 2 (latest)
        JSONObject getResponse = getPurpose(purposeId);
        Assert.assertEquals(getResponse.get("version"), 2L);

        // Add version 5
        String version5Req = "{\"version\": 5, \"description\": \"Custom jump\"}";
        JSONObject v5Resp = addPurposeVersion(purposeId, version5Req);
        Assert.assertEquals(v5Resp.get("version"), 5L);

        // Response now includes "version": 5 (latest)
        getResponse = getPurpose(purposeId);
        Assert.assertEquals(getResponse.get("version"), 5L);

        // Add version 6
        String version6Req = "{}";
        JSONObject v6Resp = addPurposeVersion(purposeId, version6Req);
        Assert.assertEquals(v6Resp.get("version"), 6L);

        // Response now includes "version": 6 (latest)
        getResponse = getPurpose(purposeId);
        Assert.assertEquals(getResponse.get("version"), 6L);

        // Add version 5 again -> 409 Conflict
        ClientResponse conflictResponse = addPurposeVersionWithResponse(purposeId, version5Req);
        Assert.assertEquals(conflictResponse.getStatusCode(), 409);

        // Get all versions
        JSONArray versions = getPurposeVersions(purposeId);
        Assert.assertEquals(versions.size(), 4);

        List<Long> versionNumbers = new ArrayList<>();
        for (Object obj : versions) {
            versionNumbers.add((Long) ((JSONObject) obj).get("version"));
        }
        Assert.assertTrue(versionNumbers.contains(1L));
        Assert.assertTrue(versionNumbers.contains(2L));
        Assert.assertTrue(versionNumbers.contains(5L));
        Assert.assertTrue(versionNumbers.contains(6L));
    }

    @Test(alwaysRun = true, groups = "wso2.is", description = "Add Receipt test", dependsOnMethods = {"testAddPurpose"})
    public void testAddReceipt() {

        String piiPrincipalId = "admin";
        String service = "travelocity.com";
        String serviceDisplayName = "Travelocity";
        String serviceDescription = "Travel City Guide";
        String consentType = "Sample";
        String collectionMethod = "Web";
        String jurisdiction = "NC";
        String language = "en-US";
        String policyURL = "http://test.com";

        JSONObject response = addReceipt(piiPrincipalId, service, serviceDisplayName, serviceDescription,
                consentType, collectionMethod, jurisdiction, language, policyURL);

        Assert.assertEquals(response.get("piiPrincipalId"), piiPrincipalId);
        Assert.assertEquals(response.get("language"), language);
    }

    private JSONObject addPIICategory(String name, String description) {

        RestClient restClient = new RestClient();
        Resource piiCatResource = restClient.resource(consentEndpoint + "/" + "pii-categories");

        String addPIICatString =
                "{\"piiCategory\": " + "\"" + name + "\"" + ", \"description\": " + "\"" + description + "\" , " +
                        "\"sensitive\": \"" + true + "\"}";

        String response = piiCatResource.
                contentType(MediaType.APPLICATION_JSON_TYPE).
                accept(MediaType.APPLICATION_JSON).
                header(HttpHeaders.AUTHORIZATION, getBasicAuthHeader(userInfo)).
                post(String.class,
                addPIICatString);

        return (JSONObject) JSONValue.parse(response);
    }

    private JSONObject addPurposeCategory(String name, String description) {

        RestClient restClient = new RestClient();
        Resource piiCatResource = restClient.resource(consentEndpoint + "/" + "purpose-categories");

        String addPurposeCatString = "{\"purposeCategory\": " + "\"" + name + "\"" + ", \"description\": " + "\"" +
                description + "\"}";

        String response = piiCatResource.
                contentType(MediaType.APPLICATION_JSON_TYPE).
                accept(MediaType.APPLICATION_JSON).
                header(HttpHeaders.AUTHORIZATION, getBasicAuthHeader(userInfo)).
                post(String.class, addPurposeCatString);

        return (JSONObject) JSONValue.parse(response);
    }

    private JSONObject addPurpose(String name, String description, String group, String groupType) {

        RestClient restClient = new RestClient();
        Resource piiCatResource = restClient.resource(consentEndpoint + "/" + "purposes");

        String addPurposeString = "{" +
                                  "  \"purpose\": \"" + name + "\"," +
                                  "  \"description\": \"" + description + "\"," +
                                  "  \"group\": \"" + group + "\"," +
                                  "  \"groupType\": \"" + groupType + "\"," +
                                  "  \"piiCategories\": [" +
                                  "    {" +
                                  "      \"piiCategoryId\": 1," +
                                  "      \"mandatory\": true" +
                                  "    }" +
                                  "  ]" +
                                  "}";

        String response = piiCatResource.
                contentType(MediaType.APPLICATION_JSON_TYPE).
                accept(MediaType.APPLICATION_JSON).
                header(HttpHeaders.AUTHORIZATION, getBasicAuthHeader(userInfo)).
                post(String.class, addPurposeString);

        return (JSONObject) JSONValue.parse(response);
    }

    private JSONObject addReceipt(String piiPrincipalId, String service, String serviceDisplayName, String
            serviceDescription, String consentType, String collectionMethod, String jurisdiction, String language,
                                  String policyURL) {

        RestClient restClient = new RestClient();
        Resource piiCatResource = restClient.resource(consentEndpoint);

        String addReceiptString = "{" +
                "  \"services\": [" +
                "    {" +
                "      \"service\": \"" + service + "\"," +
                "      \"serviceDisplayName\": \"" + serviceDisplayName + "\"," +
                "      \"serviceDescription\": \"" + serviceDescription + "\"," +
                "      \"purposes\": [" +
                "        {" +
                "          \"purposeId\": 1," +
                "          \"purposeCategoryId\": [" +
                "            1" +
                "          ]," +
                "          \"consentType\": \"" + consentType + "\"," +
                "          \"piiCategory\": [" +
                "            {" +
                "              \"piiCategoryId\": 1," +
                "              \"validity\": \"3\"" +
                "            }" +
                "          ]," +
                "          \"primaryPurpose\": true," +
                "          \"termination\": \"string\"," +
                "          \"thirdPartyDisclosure\": true," +
                "          \"thirdPartyName\": \"string\"" +
                "        }" +
                "      ]" +
                "    }" +
                "  ]," +
                "  \"collectionMethod\": \"" + collectionMethod + "\"," +
                "  \"jurisdiction\": \"" + jurisdiction + "\"," +
                "  \"language\": \"" + language + "\"," +
                "  \"policyURL\": \"" + policyURL + "\"" +
                "}";

        String response = piiCatResource.
                contentType(MediaType.APPLICATION_JSON_TYPE).
                accept(MediaType.APPLICATION_JSON).
                header(HttpHeaders.AUTHORIZATION, getBasicAuthHeader(userInfo)).
                post(String.class, addReceiptString);

        return (JSONObject) JSONValue.parse(response);
    }

    private JSONObject getPurpose(Long purposeId) {

        RestClient restClient = new RestClient();
        Resource resource = restClient.resource(consentEndpoint + "/purposes/" + purposeId);
        String response = resource.
                accept(MediaType.APPLICATION_JSON).
                header(HttpHeaders.AUTHORIZATION, getBasicAuthHeader(userInfo)).
                get(String.class);

        return (JSONObject) JSONValue.parse(response);
    }

    private JSONObject addPurposeVersion(Long purposeId, String payload) {

        ClientResponse response = addPurposeVersionWithResponse(purposeId, payload);
        Assert.assertEquals(response.getStatusCode(), 201);
        return (JSONObject) JSONValue.parse(response.getEntity(String.class));
    }

    private ClientResponse addPurposeVersionWithResponse(Long purposeId, String payload) {

        RestClient restClient = new RestClient();
        Resource resource = restClient.resource(consentEndpoint + "/purposes/" + purposeId + "/versions");
        return resource.
                contentType(MediaType.APPLICATION_JSON_TYPE).
                accept(MediaType.APPLICATION_JSON).
                header(HttpHeaders.AUTHORIZATION, getBasicAuthHeader(userInfo)).
                post(payload);
    }

    private JSONArray getPurposeVersions(Long purposeId) {

        RestClient restClient = new RestClient();
        Resource resource = restClient.resource(consentEndpoint + "/purposes/" + purposeId + "/versions");
        String response = resource.
                accept(MediaType.APPLICATION_JSON).
                header(HttpHeaders.AUTHORIZATION, getBasicAuthHeader(userInfo)).
                get(String.class);

        return (JSONArray) JSONValue.parse(response);
    }
}
