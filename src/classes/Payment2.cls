public with sharing class Payment2 {

	/**
	 * Get transactions for the Transaction Management App used by NIST.
	 *
	 * @param accountType The account that a payment is attributed to.  'Services', 'Events', or 'Privacy Shield'.
	 * @param paymentMethod The way the payment was made.  'Credit Card' or 'ACH'.
	 * @param transactionType Whether the transaction was a 'Payment' or a 'Refund'.
	 * @param fromDateString The starting date from which to search for transactions.
	 * @param toDateString The ending date used in searching for transactions.
	 */
	@AuraEnabled(cacheable=true)
	public static List<Payment2__c> getTransactions(String accountType, String paymentMethod, String transactionType, String fromDateString, String toDateString) {
		try {
			String transactionStatus;
			String recordTypeId;
			String paymentType;

			//From Datetime
			Date fromDate = Date.parse(fromDateString);
			Datetime fromDatetime = Datetime.newInstance(fromDate.year(), fromDate.month(), fromDate.day(),0,0,0);

			//To Datetime
			Date toDate = Date.parse(toDateString);
			Datetime toDatetime =  Datetime.newInstance(toDate.year(), toDate.month(), toDate.day(),23,59,59);

			Map<String, Id> rtMap = Utils.getRecordTypeIdMap('Payment2__c');

			if (transactionType == 'Payment') {
				recordTypeId = rtMap.get('Credit_Card_or_ACH_Payment');
				if (paymentMethod == 'Credit Card') {
					paymentType = 'PLASTIC_CARD';
					transactionStatus = 'Success';
				} else if (paymentMethod == 'ACH') {
					paymentType = 'ACH';
					transactionStatus = 'Received';
				}
			} else if (transactionType == 'Refund') {
				recordTypeId = rtMap.get('Credit_Card_Refund');
				transactionStatus = 'Success';
				paymentType = 'PLASTIC_CARD';
			}

			return PaymentsSelector2.newInstance().selectByTransactionDetails(accountType, paymentType, recordTypeId, transactionStatus, fromDatetime, toDatetime);
		} catch (Exception e) {
			throw new AuraHandledException(e.getMessage());
		}
	}

	/**
	 * Get an Order record, given an Order Id.
	 *
	 * @param orderId An order Id.
	 */
	@AuraEnabled(cacheable=true)
	public static Order getOrder(String orderId) {
		try {
			Set<Id> orderIds = new Set<Id>{orderId};
			List<Order> orders = OrdersSelector.newInstance().selectById(orderIds);
			if (orders.size() > 0) {
				return orders[0];
			}
			return null;
		} catch (Exception e) {
			throw new AuraHandledException(e.getMessage());
		}
	}

	/**
	 * Get an Order record, given an Order Id.  This method is typically used for Reduction Orders because it returns details about the Original Order.
	 *
	 * @param orderId An order Id.
	 * @param normalOrders Whether normal (non-reduction) orders should be returned.
	 * @param reductionOrders Whether Reduction Orders should be returned.
	 * @param nonPaidOnly Whether only non-paid orders should be returned.  If true, do not make paidOnly true.
	 * @param paidOnly Whether only paid orders should be returned.  If true, do not make nonPaidOnly true.
	 */
	@AuraEnabled(cacheable=true)
	public static Order getOrderWithReductionOrderDetails(String orderId, Boolean normalOrders, Boolean reductionOrders, Boolean nonPaidOnly, Boolean paidOnly) {
		try {
			Set<Id> orderIds = new Set<Id>{orderId};
			List<Order> orders = OrdersSelector.newInstance().selectWithReductionOrderDetails(orderIds, normalOrders, reductionOrders, nonPaidOnly, paidOnly);
			if (orders.size() > 0) {
				return orders[0];
			}
			return null;
		} catch (Exception e) {
			throw new AuraHandledException(e.getMessage());
		}
	}

	/**
	 * Get Order records, given a Contract Id.
	 *
	 * @param contractId A Contract Id.
	 * @param normalOrders Whether normal (non-reduction) orders should be returned.
	 * @param reductionOrders Whether Reduction Orders should be returned.
	 * @param nonPaidOnly Whether only non-paid orders should be returned.  If true, do not make paidOnly true.
	 * @param paidOnly Whether only paid orders should be returned.  If true, do not make nonPaidOnly true.
	 */
	@AuraEnabled(cacheable=true)
	public static List<Order> getOrdersByContractId(String contractId, Boolean normalOrders, Boolean reductionOrders, Boolean nonPaidOnly, Boolean paidOnly) {
		try {
			Set<Id> contractIds = new Set<Id>{contractId};
			List<Order> orders = OrdersSelector.newInstance().selectByContractId(contractIds, normalOrders, reductionOrders, nonPaidOnly, paidOnly);
			return orders;
		} catch (Exception e) {
			throw new AuraHandledException(e.getMessage());
		}
	}

	/**
	 * Create a payment record and get user details for the payment.  After calling this method, the user will be on the Pay.gov site.
	 * Do not combine startElectronicPayment() and authorizePayment().  They are broken up this way because authorizePayment() includes a callout and startElectronicPayment() include DML.
	 *
	 * @param accountType The account that a payment is attributed to.  'Services', 'Events', or 'Privacy Shield'.
	 * @param contractId A Contract Id.
	 * @param orderIds An array of Order Ids.
	 * @param userId Either null or empty string if you want the current user's information to be the default values at pay.gov.  Pass in a user id if you want someone else's information to be the default values.
	 * @param paymentPage The page on which the transaction is being processed.  Canceled payments get redirected back here.
	 * @param paymentConfirmationPage The page to which pay.gov returns to in Salesforce if the payment was authorized.
	 * @param objectApiName 'Contract' or 'Order', depending on whether the payment is being made on a 'Contract' or 'Order' page.
	 * @param recordId The Contract Id or Order Id of the page from which payment is attempted.
	 */
	@AuraEnabled(cacheable=false)
	public static String startElectronicPayment(String accountType, String contractId, String[] orderIds, String userId,
		String paymentPage, String paymentConfirmationPage, String objectApiName, String recordId) {
		try {
			RecordLog.push('Payment.createPayment');
			RecordLog.message('Order Ids: ' + orderIds);
			//Get the User Id for the current user if none was passed in.
			if (String.isBlank(userId)) {
				userId = UserInfo.getUserId();
			}
			//Convert orderIds String array to set of Id
			Set<Id> orderIdSet = (Set<Id>)JSON.deserialize(JSON.serialize(orderIds), Set<Id>.class);
			List<Order> orders = OrdersSelector.newInstance().selectById(orderIdSet);
			Payment2__c payment = new Payment2__c();
			payment.Account_Type__c = accountType;
			RecordLog.message('Account Type: ' + accountType);
			payment.RecordTypeId = Utils.getRecordTypeNameByDeveloperName('Credit_Card_or_ACH_Payment', 'Payment2__c');
			RecordLog.message('Record Type Id: ' + payment.RecordTypeId);
			payment.Contract__c = contractId;
			RecordLog.message('Contract Id: ' + contractId);
			Decimal totalAmount = 0.00;
			for (Order order: orders) {
				totalAmount += order.TotalAmount;
			}
			payment.Transaction_Amount__c = totalAmount;
			RecordLog.message('Transaction Amount: ' + totalAmount);
			RecordLog.message('Inserting Payment');
			try {
				fflib_SObjectUnitOfWork uow = new fflib_SObjectUnitOfWork(new List<SObjectType> {Payment2__c.SObjectType});
				uow.registerNew(payment);
				uow.commitWork();
			} catch (Exception e) {
				RecordLog.message('Exception: ' + e.getMessage());
				RecordLog.emit('No Payment Id');
				throw e;
			}
			RecordLog.message('Payment inserted');
			//Since Name is an Auto-Number field, must query the paymentObject to get the value
			List<Payment2__c> payments = PaymentsSelector2.newInstance().selectById(new Set<Id> {payment.Id});
			String paymentIdentifier = payments[0].Name;
			RecordLog.message('Payment Identifier: ' + paymentIdentifier);
			String remoteAccountName = getRemoteAccountName(accountType);
			RecordLog.message('Remote Account Name: ' + remoteAccountName);

			//Gather data to send to the payment processor
			List<User> users = UsersSelector.newInstance().selectById(new Set<Id> {userId});
			PaymentAuthenticationDetails details = new PaymentAuthenticationDetails();
			details.paymentId = payment.Id;
			details.paymentIdentifier = paymentIdentifier;
			details.transactionType = 'Sale';
			details.transactionAmount = String.valueOf(totalAmount);
			String baseUrl = getBaseUrl();
			//orderIds contains a starting and ending parentheses.  Remove them.
			String orderIdsString = '' + orderIds;  //Convert orderIds array to a string
			orderIdsString = orderIdsString.removeStart('(');
			orderIdsString = orderIdsString.removeEnd(')');
			details.successUrl = baseUrl + '/' + paymentConfirmationPage + '?paymentId=' + payment.Id + '&acctType='
				+ accountType + '&orderIds=' + orderIdsString + '&objectApiName=' + objectApiName + '&recordId=' + recordId;
			RecordLog.message('Success Url = ' + details.successUrl);
			details.cancelUrl = baseUrl + '/' + paymentPage + '?cancel=true';
			RecordLog.message('Cancel Url' + details.cancelUrl);
			details.accountHolderName = Accents.removeDiacritics(users[0].Name);
			RecordLog.message('Account Holder Name: ' + details.accountHolderName);
			details.billingAddress = users[0].Contact.MailingStreet != null ? Utils.convMultiLineTextToOne(users[0].Contact.MailingStreet) : null;
			RecordLog.message('Billing Address: ' + details.billingAddress);
			details.billingCity = users[0].Contact.MailingCity;
			RecordLog.message('Billing City: ' + details.billingCity);
			details.billingStateCode = users[0].Contact.MailingStateCode;
			RecordLog.message('Billing State Code: ' + details.billingStateCode);
			details.billingZip = users[0].Contact.MailingPostalCode;
			RecordLog.message('Billing Zip Code: ' + details.billingZip);
			details.billingCountryCode = Utils.getCountryCodeFromAlpha2(
				users[0].Contact.MailingCountryCode, Utils.CountryCodeType.NUMERIC);
			RecordLog.message('Billing Country Code: ' + details.billingCountryCode);
			//details.email = user.Contact.Email;  //Do not allow pluses if sending email to pay.gov
			details.accountType = accountType;
			details.remoteAccountName = remoteAccountName;
			RecordLog.emit(payment.Id);
			return JSON.serialize(details);
		} catch(Exception e) {
			throw new AuraHandledException(e.getMessage());
		}
	}

	/**
	 * Authorize an electronic payment.  This method includes a callout to the payment processor's site (Pay.gov).
	 * Do not combine startElectronicPayment() and authorizePayment().  They are broken up this way because authorizePayment() includes a callout and startElectronicPayment() include DML.
	 *
	 * @param authenticationDetailsString A JSON string of data that will be used by the payment processor as default values for the payment.
	 */
	@AuraEnabled(cacheable=false)
	public static String authorizePayment(String authenticationDetailsString) {
		try {
			Payment2.PaymentAuthenticationDetails authenticationDetails = (Payment2.PaymentAuthenticationDetails)JSON.deserialize(authenticationDetailsString, PaymentAuthenticationDetails.class);
			IPayment payment = (IPayment) di_Injector.Org.getInstance('PaymentProcessor');
			return payment.authorizePayment(authenticationDetails);
		} catch(Exception e) {
			throw new AuraHandledException(e.getMessage());
		}
	}

	/**
	 * Confirm with the payment processor that the authorized payment should be charged.
	 *
	 * @param accountType The account that a payment is attributed to.  'Services', 'Events', or 'Privacy Shield'.
	 * @param paymentId The Payment Id.
	 * @param token The token previously returned from Pay.gov when the transaction was authorized.
	 * @param orderIds An array of Order Ids, which are the orders being paid for.
	 */
	@AuraEnabled(cacheable=false)
	public static String confirmPayment(String accountType, String paymentId, String token, String[] orderIds) {
		try {
			IPayment payment = (IPayment) di_Injector.Org.getInstance('PaymentProcessor');
			String remoteAccountName = getRemoteAccountName(accountType);
			return payment.confirmPayment(remoteAccountName, paymentId, token, accountType, orderIds);
		} catch(Exception e) {
			throw new AuraHandledException(e.getMessage());
		}
	}

	/**
	 * Format User Info field values for sending to pay.gov
	 *
	 * @param userElement A value that will be passed to pay.gov.
	 * @param charLimit The character limit allowed by pay.gov.
	 */
	// Formats user info field values for sending to pay.gov
	public static String userElementFormat(String userElement, Integer charLimit) {
		if (userElement != null) {
			userElement = userElement.length() > charLimit ? userElement.substring(0, charLimit) : userElement;
		}
		return userElement;
	}

	/**
	 * Get the current fiscal year
	 */
	public static String getCurrentFiscalYear() {
		Date currentDate = Date.today();  //Check for GMT
		Integer year = currentDate.year();
		Integer month = currentDate.month();
		if (month > 9) {
			year++;
		}
		return String.valueOf(year);
	}

	/**
	 * Get the time zone offset, which allows GMT dates to be converted to Washington DC time.
	 */
	public static Integer getTimeZoneOffset() {
		Timezone tz = Timezone.getTimeZone('America/New_York');
		// Create a date after the 2007 shift of DST into November
		DateTime dt = system.now();
		//system.debug(tz.getOffset(dt));  //-18000000 (= -5 hours = EST)
		Integer offsetSeconds = tz.getOffset(dt)/1000*-1;  //1000 is to convert milliseconds to seconds and -1 is to add seconds instead of subtract
		return offsetSeconds;
	}

	/**
	 * Get the Salesforce Base URL.
	 */
	private static String getBaseUrl() {
		return URL.getSalesforceBaseURL().toExternalForm();
	}

	/**
	 * Get the Remote Account Name from metadata.  This is the 'Application' name used by Pay.gov.
	 */
	public static String getRemoteAccountName(String accountType) {
		//Replace spaces with underscores (e.g. Privacy Shield = Privacy_Shield)
		String accountMetaDataName = accountType.replace(' ', '_') + '_Remote_Account__c';
		Map<String, Object> paymentSettingsMap = CustomMetadataSelector.getPaymentSettings('PayGov');
		return (String) paymentSettingsMap.get(accountMetaDataName);
	}

	public class PaymentAuthenticationDetails {
		public Id paymentId;
		public String paymentIdentifier;
		public String remoteAccountName;
		public String transactionType;
		public String transactionAmount;
		public String successUrl;
		public String cancelUrl;
		public String accountHolderName;
		public String billingAddress;
		public String billingAddress2;
		public String billingCity;
		public String billingStateCode;
		public String billingZip;
		public String billingCountryCode;
		public String email;
		public String accountType;
	}

}