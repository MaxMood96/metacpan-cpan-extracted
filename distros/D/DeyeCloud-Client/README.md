# **NAME**

**DeyeCloud::Client** - perl5 client to Deye Cloud API

# **DESCRIPTION**

This module implements all operations as described in [Deye
Cloud developer guide](https://developer.deyecloud.com/api) (and some operations not described).

# **CAVEATS**

- This module requires perl v5.10+ since it uses 'signatures' feature;
- All options and results names have the same names as passed to or returned
by Deye Cloud. I don't like their naming conventions (or rather, the lack
thereof) too. However, they are (partially) described in Deye Cloud developer
guide, so let's assume this is not the worst case.

# **SYNOPSIS**

    use DeyeCloud::Client;
    
    my $deye = DeyeCloud::Client->new();

    $deye->method('GET');
    $deye->baseurl('https://www.deyecloud.com/device-s');
    my $device = $deye->call('device/originalData', 'deviceId' => $device_id);

    $deye->error
        ? die $deye->errmsg
        : printf "Battery SOC = %.2f\n", $device->{'BMS_SOC'};
    
    # or almost the same using wrapper method:
    
    $device = $deye->status('deviceId' => $device_id);

    $deye->error
        ? die $deye->errmsg
        : printf "Battery SOC = %.2f\n", $device->BMS_SOC;

# **METHODS**

- **new(OPTIONS)**

    **DeyeCloud::Client** object constructor. Is used as follows:

        my $deye = DeyeCloud::Client->new('token' => 'AUTHORIZATION_TOKEN');

    Supported options are:

    - **baseurl** => STRING

        API root URI. Depends on which data you want to retrieve (differs for station
        and device). Default value is 'https://eu1-developer.deyecloud.com/v1.0',
        which is used for new token and station data retrieval.

    - **method** => STRING

        HTTP method will be used to perform Deye Cloud server queries. Depends
        on server. Default value is 'POST', which is used for new token and station
        data retrieval.

    - **sslcheck** => BOOLEAN

        Perform SSL certificate check (if set to 'true', default) or not.

    - **timeout** => INTEGER

        Cloud server query timeout. Default value is 15 seconds.

    - **token** => STRING

        Authorization token. Can be either set or retrieved later using 'token'
        method.

- **token(STRING | HASH)**

    This method is used for operations with authorization token as follows:

        # Get current authorization token
        #
        my $token = $deye->token();
        
        # Set authorization token to a new value
        #
        $deye->token('AUTHORIZATION_TOKEN');
        
        # Generate and return a new authorization token
        #
        $deye->token(
            'appId'     => 'APPLICATION_ID',
            'appSecret' => 'APPLICATION_SECRET',
            'email'     => 'ACCOUNT_EMAIL',
            'password'  => 'ACCOUNT_PASSWORD',
        );
        $deye->error
            ? die $deye->errmsg
            : printf "%s\n", $deye->token;

    Deye Cloud provides a possibility to generate a new token using a phone
    number and a country code instead of email, but this way is not implemented
    yet.

    Pay an attention, that some options are written in lower case and some -
    in lower Camel case. Just the way they are named in Deye Cloud developer guide.

    Supported options are:

    - **appId** => STRING

        Application ID (register new [here](https://developer.deyecloud.com/app) if you don't have one).

    - **appSecret** => STRING

        Application secret (see 'appId' item).

    - **email** => STRING

        Deye Cloud account email.

    - **password** => STRING

        Deye Cloud account password.

- **baseurl(STRING)**

    This method gets or sets Deye Cloud API server base URL:

        my $baseurl = $deye->baseurl;
        $deye->baseurl('https://eu1-developer.deyecloud.com/v1.0');

- **method(STRING)**

    Get or set HTTP method used to send query data to Deye Cloud API
    servers. Endpoints and appropriate methods are described in Deye
    Cloud developer guide.

        my $method = $deye->method;
        $deye->method('GET');

- **call(STRING, HASH)**

    This is universal method to conversate with Deye Cloud API servers
    as follows:

        # Setting API server base URL and method is not required in
        # every case. However, pay an attention that device data
        # retrieval CAN require setting those variables explicitly!
        #
        $deye->baseurl('https://eu1-developer.deyecloud.com/v1.0');
        $deye->method('POST');
        my $data = $deye->call('station/latest', 'stationId' => INTEGER);

    Available options list depends on endpoint. Most endpoints are described
    in Deye Cloud developer guide.

- **status(HASH)**

    Wrapper method to get latest station or device status. Implicitly sets
    the right method and baseurl, both are restored on return. Main difference
    between **call()** and **status()** methods is that **call()** returns reference
    to a hash and **status()** returns a blessed reference to a **DeyeCloud::Client::Device**
    or **DeyeCloud::Client::Station** class object. You can use either a variable name
    or a getter method in order to refer to a specific variable:

        my $status = $deye->status('deviceId' => INTEGER);
        
        printf "Grid voltage, L1: %.2f\n", $status->G_V_L1;
        
        # or, the same in another way:
        
        printf "Grid voltage, L1: %.2f\n", $status->{'G_V_L1'};

    Available options are:

    - **deviceId** => INTEGER

        Deye Cloud device ID.

    - **stationId** => INTEGER

        Deye Cloud station ID.

- **error()**

    Takes no arguments. Returns 'false' if **DeyeCloud::Client** object is
    defined and error flag is not set and 'true' otherwise.

- **errno()**

    Takes no arguments. Returns error code. '**0**' is returned for no error.

- **errmsg()**

    Takes no arguments. Returns error message. Empty string ('') is
    returned for no error.

- **seterror(ERROR \[, LIST\])**

    Set or reset (when called with no arguments) error flag, error code and error
    message. It is called implicitly when any service method is called and should
    not be called explicitly in any circumstances.

# **AUTHORS**                                                                                                                   

- Volodymyr Pidgornyi, vp&lt;at>dtel-ix.net;                                                                               

# **CHANGELOG**

### v0.0.2 - 2026-02-23

- Added readable and predictable aliases to device parameters names
(e. g. 'gridV1' instead of 'G\_V\_L1');
- Minor documentation updates.

### v0.0.1 - 2026-02-22

- Initial public release.

# **TODO**

- Add token retrieval using country code / phone number pair in addition
to email.

# **LINKS**

- [Deye Cloud developer guide](https://developer.deyecloud.com/api);
