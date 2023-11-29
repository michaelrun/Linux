# Registration
## Registration by PCKIDRetrievalTool
```
root@scg-sprxx:/opt/intel/sgx-pck-id-retrieval-tool# ./PCKIDRetrievalTool

Intel(R) Software Guard Extensions PCK Cert ID Retrieval Tool Version 1.19.100.3

Registration status has been set to completed status.
pckid_retrieval.csv has been generated successfully!
```

:exclamation: In above test, linux-sgx use tag sgx_2.19, but built SGXDataCenterAttestationPrimitives seperately with tag DCAP_1.19, since DCAP_1.16 which linux_src sgx_2.19 depends on

:exclamation: DCAP_1.16 can not work with sgx_2.19 

:exclamation: Sgx-pck-id-retrieval-tool version must match with SGXSDK and PSW

## Get and Put Collaterals to PCCS

root@scg-sprxx:/home/user01/src/SGXDataCenterAttestationPrimitives/tools/PccsAdminTool# export https_proxy=http://proxy-host:proxy-port \
root@scg-sprxx:/home/user01/src/SGXDataCenterAttestationPrimitives/tools/PccsAdminTool# export http_proxy=http://proxy-host:proxy-port

### Collect platform data that was retrieved by PCK ID retrieval tool into one json file. This file can be used as input of "fetch" command

  `./pccsadmin.py collect [-h] [-d DIRECTORY] [-o OUTPUT_FILE]`

  optional arguments:
          -h, --help            show this help message and exit
          -d DIRECTORY, --directory DIRECTORY
                                The directory which stores the platform data(*.csv) retrieved by PCK ID retrieval tool; default: ./
          -o OUTPUT_FILE, --output_file OUTPUT_FILE
                                The output json file name; default: platform_list.json
```
root@scg-spr05:/home/guoqing/src/SGXDataCenterAttestationPrimitives/tools/PccsAdminTool# ./pccsadmin.py collect -d . -o platform_list.json
platform_list.json  saved successfully.
```
###  Fetch platform collateral data from Intel PCS based on the registration data
`./pccsadmin.py fetch [-h] [-u URL] [-i INPUT_FILE] [-o OUTPUT_FILE]` 
```
  optional arguments:
          -h, --help            show this help message and exit
          -i INPUT_FILE, --input_file INPUT_FILE
                                The input file name for platform list; default: platform_list.json
          -o OUTPUT_FILE, --output_file OUTPUT_FILE
                                The output file name for platform collaterals; default: platform_collaterals.json
          -u URL, --url URL     The URL of the Intel PCS service; default: https://api.trustedservices.intel.com/sgx/certification/v4/
          -p PLATFORM, --platform PLATFORM
                                Specify what kind of platform you want to fetch FMSPCs and tcbinfos for; default: all", choices=['all','client','E3','E5']
          -c, --crl             Retrieve only the certificate revocation list (CRL). If an input file is provided, this option will be ignored.
```
Example:
```
root@scg-sprxx:/home/user01/src/SGXDataCenterAttestationPrimitives/tools/PccsAdminTool# ./pccsadmin.py fetch -i platform_list.json
Please input ApiKey for Intel PCS:
Would you like to remember Intel PCS ApiKey in OS keyring? (y/n)n
https://api.trustedservices.intel.com/sgx/certification/v4/pckcrl?ca=processor&encoding=der
https://api.trustedservices.intel.com/sgx/certification/v4/pckcrl?ca=platform&encoding=der
https://api.trustedservices.intel.com/sgx/certification/v4/pckcerts
Some certificates are 'Not available'. Do you want to save the list?(y/n)y
Please input file name (Press enter to use default name not_available.json):
Please check not_available.json for 'Not available' certificates.
https://api.trustedservices.intel.com/sgx/certification/v4/fmspcs?platform=all
https://api.trustedservices.intel.com/sgx/certification/v4/tcb?fmspc=00706A100000
https://api.trustedservices.intel.com/tdx/certification/v4/tcb?fmspc=00706A100000

https://api.trustedservices.intel.com/sgx/certification/v4/tcb?fmspc=20606C040000
https://api.trustedservices.intel.com/tdx/certification/v4/tcb?fmspc=20606C040000

https://api.trustedservices.intel.com/sgx/certification/v4/tcb?fmspc=10C06F000000
https://api.trustedservices.intel.com/tdx/certification/v4/tcb?fmspc=10C06F000000
https://api.trustedservices.intel.com/sgx/certification/v4/tcb?fmspc=30606A000000
https://api.trustedservices.intel.com/tdx/certification/v4/tcb?fmspc=30606A000000

https://api.trustedservices.intel.com/sgx/certification/v4/tcb?fmspc=60C06F000000
https://api.trustedservices.intel.com/tdx/certification/v4/tcb?fmspc=60C06F000000
https://api.trustedservices.intel.com/sgx/certification/v4/tcb?fmspc=E0806F000000
https://api.trustedservices.intel.com/tdx/certification/v4/tcb?fmspc=E0806F000000

https://api.trustedservices.intel.com/sgx/certification/v4/tcb?fmspc=10A06F010000
https://api.trustedservices.intel.com/tdx/certification/v4/tcb?fmspc=10A06F010000
https://api.trustedservices.intel.com/sgx/certification/v4/tcb?fmspc=D0806F000000
https://api.trustedservices.intel.com/tdx/certification/v4/tcb?fmspc=D0806F000000
https://api.trustedservices.intel.com/sgx/certification/v4/tcb?fmspc=00806f050000
https://api.trustedservices.intel.com/tdx/certification/v4/tcb?fmspc=00806f050000
https://api.trustedservices.intel.com/sgx/certification/v4/tcb?fmspc=20806F040000
https://api.trustedservices.intel.com/tdx/certification/v4/tcb?fmspc=20806F040000

https://api.trustedservices.intel.com/sgx/certification/v4/tcb?fmspc=00906EA10000
https://api.trustedservices.intel.com/tdx/certification/v4/tcb?fmspc=00906EA10000

https://api.trustedservices.intel.com/sgx/certification/v4/tcb?fmspc=50806F000000
https://api.trustedservices.intel.com/tdx/certification/v4/tcb?fmspc=50806F000000
https://api.trustedservices.intel.com/sgx/certification/v4/tcb?fmspc=00706E470000
https://api.trustedservices.intel.com/tdx/certification/v4/tcb?fmspc=00706E470000

https://api.trustedservices.intel.com/sgx/certification/v4/tcb?fmspc=20806EB70000
https://api.trustedservices.intel.com/tdx/certification/v4/tcb?fmspc=20806EB70000

https://api.trustedservices.intel.com/sgx/certification/v4/tcb?fmspc=00606C040000
https://api.trustedservices.intel.com/tdx/certification/v4/tcb?fmspc=00606C040000

https://api.trustedservices.intel.com/sgx/certification/v4/tcb?fmspc=30A06D050000
https://api.trustedservices.intel.com/tdx/certification/v4/tcb?fmspc=30A06D050000
https://api.trustedservices.intel.com/sgx/certification/v4/tcb?fmspc=00606A000000
https://api.trustedservices.intel.com/tdx/certification/v4/tcb?fmspc=00606A000000

https://api.trustedservices.intel.com/sgx/certification/v4/tcb?fmspc=B0C06F000000
https://api.trustedservices.intel.com/tdx/certification/v4/tcb?fmspc=B0C06F000000
https://api.trustedservices.intel.com/sgx/certification/v4/tcb?fmspc=90C06F000000
https://api.trustedservices.intel.com/tdx/certification/v4/tcb?fmspc=90C06F000000
https://api.trustedservices.intel.com/sgx/certification/v4/tcb?fmspc=00806EB70000
https://api.trustedservices.intel.com/tdx/certification/v4/tcb?fmspc=00806EB70000

https://api.trustedservices.intel.com/sgx/certification/v4/tcb?fmspc=00806F050000
https://api.trustedservices.intel.com/tdx/certification/v4/tcb?fmspc=00806F050000
https://api.trustedservices.intel.com/sgx/certification/v4/tcb?fmspc=C0806F000000
https://api.trustedservices.intel.com/tdx/certification/v4/tcb?fmspc=C0806F000000
https://api.trustedservices.intel.com/sgx/certification/v4/tcb?fmspc=00906ED50000
https://api.trustedservices.intel.com/tdx/certification/v4/tcb?fmspc=00906ED50000

https://api.trustedservices.intel.com/sgx/certification/v4/tcb?fmspc=00906EC50000
https://api.trustedservices.intel.com/tdx/certification/v4/tcb?fmspc=00906EC50000

https://api.trustedservices.intel.com/sgx/certification/v4/tcb?fmspc=90806F000000
https://api.trustedservices.intel.com/tdx/certification/v4/tcb?fmspc=90806F000000

https://api.trustedservices.intel.com/sgx/certification/v4/tcb?fmspc=00706A800000
https://api.trustedservices.intel.com/tdx/certification/v4/tcb?fmspc=00706A800000

https://api.trustedservices.intel.com/sgx/certification/v4/tcb?fmspc=00806F040000
https://api.trustedservices.intel.com/tdx/certification/v4/tcb?fmspc=00806F040000

https://api.trustedservices.intel.com/sgx/certification/v4/tcb?fmspc=20A06F000000
https://api.trustedservices.intel.com/tdx/certification/v4/tcb?fmspc=20A06F000000
https://api.trustedservices.intel.com/sgx/certification/v4/tcb?fmspc=00906EC10000
https://api.trustedservices.intel.com/tdx/certification/v4/tcb?fmspc=00906EC10000

https://api.trustedservices.intel.com/sgx/certification/v4/tcb?fmspc=80C06F000000
https://api.trustedservices.intel.com/tdx/certification/v4/tcb?fmspc=80C06F000000
https://api.trustedservices.intel.com/sgx/certification/v4/tcb?fmspc=30806F040000
https://api.trustedservices.intel.com/tdx/certification/v4/tcb?fmspc=30806F040000

https://api.trustedservices.intel.com/sgx/certification/v4/tcb?fmspc=00A067110000
https://api.trustedservices.intel.com/tdx/certification/v4/tcb?fmspc=00A067110000

https://api.trustedservices.intel.com/sgx/certification/v4/tcb?fmspc=00806EA60000
https://api.trustedservices.intel.com/tdx/certification/v4/tcb?fmspc=00806EA60000

https://api.trustedservices.intel.com/sgx/certification/v4/tcb?fmspc=A0806F000000
https://api.trustedservices.intel.com/tdx/certification/v4/tcb?fmspc=A0806F000000
https://api.trustedservices.intel.com/sgx/certification/v4/tcb?fmspc=80806F000000
https://api.trustedservices.intel.com/tdx/certification/v4/tcb?fmspc=80806F000000
https://api.trustedservices.intel.com/sgx/certification/v4/tcb?fmspc=00906EA50000
https://api.trustedservices.intel.com/tdx/certification/v4/tcb?fmspc=00906EA50000

https://api.trustedservices.intel.com/sgx/certification/v4/tcb?fmspc=20906EC10000
https://api.trustedservices.intel.com/tdx/certification/v4/tcb?fmspc=20906EC10000

https://api.trustedservices.intel.com/sgx/certification/v4/tcb?fmspc=F0806F000000
https://api.trustedservices.intel.com/tdx/certification/v4/tcb?fmspc=F0806F000000

https://api.trustedservices.intel.com/sgx/certification/v4/tcb?fmspc=00806F000000
https://api.trustedservices.intel.com/tdx/certification/v4/tcb?fmspc=00806F000000

https://api.trustedservices.intel.com/sgx/certification/v4/tcb?fmspc=00906EB10000
https://api.trustedservices.intel.com/tdx/certification/v4/tcb?fmspc=00906EB10000

https://api.trustedservices.intel.com/sgx/certification/v4/qe/identity
https://api.trustedservices.intel.com/tdx/certification/v4/qe/identity
https://api.trustedservices.intel.com/sgx/certification/v4/qve/identity
platform_collaterals.json  saved successfully.

root@scg-sprxx:/home/user01/src/SGXDataCenterAttestationPrimitives/tools/PccsAdminTool#
```



###  Put platform collateral data to PCCS cache db
```
  ./pccsadmin.py put [-h] [-u URL] [-i INPUT_FILE]

  optional arguments:
          -h, --help            show this help message and exit
          -u URL, --url URL     The URL of the PCCS's PUT collateral API; default: https://localhost:8081/sgx/certification/v4/platformcollateral
          -i INPUT_FILE, --input_file INPUT_FILE
                                The input file name for platform collaterals; default: platform_collaterals.json

```

Example:
```
root@scg-sprxx:/home/user01/src/SGXDataCenterAttestationPrimitives/tools/PccsAdminTool# ./pccsadmin.py put -i platform_collaterals.json
Please input your administrator password for PCCS service:
Would you like to remember password in OS keyring? (y/n)n
/usr/lib/python3/dist-packages/urllib3/connectionpool.py:1020: InsecureRequestWarning: Unverified HTTPS request is being made to host 'localhost'. Adding certificate verification is strongly advised. See: https://urllib3.readthedocs.io/en/latest/advanced-usage.html#ssl-warnings
  warnings.warn(
Collaterals uploaded successfully.

Sqlite3 ./pckcache.db


```

### Now it is ready to generate quote
```
Unset http_proxy https_proxy
root@scg-sprxx:/home/user01/src/linux-sgx/external/dcap_source/SampleCode/QuoteGenerationSample# ./app
sgx_qe_set_enclave_load_policy is valid in in-proc mode only and it is optional: the default enclave load policy is persistent:
set the enclave load policy as persistent:succeed!

Step1: Call sgx_qe_get_target_info:succeed!succeed!
Step2: Call create_app_report:succeed!
Step3: Call sgx_qe_get_quote_size:succeed!
Step4: Call sgx_qe_get_quote:succeed!cert_key_type = 0x5
sgx_qe_cleanup_by_policy is valid in in-proc mode only.

 Clean up the enclave load policy:succeed!
```


### Verify Quote
```
root@scg-sprxx:/home/user01/src/linux-sgx/external/dcap_source/SampleCode/QuoteVerificationSample# ./app
Info: ECDSA quote path: ../QuoteGenerationSample/quote.dat

Trusted quote verification:
        Error: Can't load SampleISVEnclave. 0x200f

===========================================

Untrusted quote verification:
        Info: tee_get_quote_supplemental_data_version_and_size successfully returned.
        Info: latest supplemental data major version: 3, minor version: 1, size: 336
        Info: App: tee_verify_quote successfully returned.
        Warning: App: Verification completed with Non-terminal result: a002
        Info: Supplemental data Major Version: 3
        Info: Supplemental data Minor Version: 1
        Info: Advisory ID: INTEL-SA-00837

````



:memo:        | You check PCCS log to confirm above actions
```
2023-11-28 07:58:13.918 [info]: Client Request-ID : 0839afc8f8eb45fb8d9cda3ef8936336
2023-11-28 07:58:14.024 [info]: 127.0.0.1 - - [28/Nov/2023:07:58:14 +0000] "PUT /sgx/certification/v4/platformcollateral HTTP/1.1" 200 21 "-" "pccsadmin/0.
```
