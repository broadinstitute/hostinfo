#!/usr/bin/env python
from database import Database
from datetime import datetime,timedelta
from MySQLdb import OperationalError
from re import match,split
from sys import exit,stderr
from time import mktime,sleep,strftime,strptime
#import time
from urllib2 import urlopen
import json
import ConfigParser

class Warranty(object):

    def __init__(self, config):
        self.dbhost = config.get("database", "dbhost")
        self.dbuser = config.get("database", "dbuser")
        self.dbpass = config.get("database", "dbpass")
        self.dbname = config.get("database", "dbname")
        self.dellapikey = config.get("dell", "apikey")

        self.db = Database(self.dbhost, self.dbuser, self.dbpass, self.dbname)

    def gethostinfo(self):
        sqlcode='''SELECT hostname,SKU,system_type,serialnum,vendor FROM
                   warranty'''
        self.db.curs.execute(sqlcode)
        rows = self.db.curs.fetchall()

        for row in rows:
            host, sku, type, serial, vendor = row
            if "vmware" in vendor.lower():
                continue
            try:
                self.getwarranty(host, sku, type, serial, vendor)
            except OperationalError:
                self.db.rollback(e)
            except ValueError:
                continue

    def getwarranty(self, host, sku, type, serial, vendor):
        lvendor = vendor.lower()
        sleep(1)

        if "dell" in lvendor:
            url = "https://api.dell.com/support/v2/assetinfo/warranty/tags.json?svctags=%s&apikey=%s" % (serial, dellapikey)
        elif "ibm" in lvendor:
            url = ("http://www-307.ibm.com/pc/support/site.wss/warrantyLookup.do?"
                "type=%s&serial=%s&country=897&iws=off&sitestyle=lenovo" %
                (type,serial))
        elif "hp" in lvendor:
            url = ("http://h20000.www2.hp.com/bizsupport/TechSupport/"
                 "WarrantyResults.jsp?lang=en&cc=us&prodSeriesId=454811&"
                 "prodTypeId=12454&sn=%s&pn=%s&country=US&nickname=&"
                 "find=Display+Warranty+Information" % (serial,sku))
        else:
            return

        file = urlopen(url)
        lines = split('>|<',file.read())
        print lines
        dates = [convertdate(line) for line in lines if convertdate(line)]

        try:
            warranty_start = strftime("%Y-%m-%d",min(dates))
            warranty_end = strftime("%Y-%m-%d",max(dates))
        except:
            warranty_start = None
            warranty_end = None

        if warranty_start == warranty_end:
            warranty_start = None

        sqlcode='''UPDATE warranty 
                   SET start_date=%s,end_date=%s
                   WHERE hostname=%s and SKU=%s and system_type=%s 
                   and serialnum=%s and vendor=%s'''
        self.db.curs.execute(sqlcode, (warranty_start, warranty_end, host,
                            sku, type, serial, vendor))

    def getDellWarranty(self, host, serial):
        baseurl = "https://api.dell.com/support/v2/assetinfo/warranty/tags.json"

        query = "svctags=%s&apikey=%s" % (serial, self.dellapikey)
        url = "%s?%s" % (baseurl, query)

        f = urlopen(url)
        data = f.read()

        i = json.loads(data)
        info = i["GetAssetWarrantyResponse"]["GetAssetWarrantyResult"]["Response"]["DellAsset"];

        print "Ship Date: %s" % info["ShipDate"]
        print "Order Number: %s" % info["OrderNumber"]
        print "Customer Number: %s" % info["CustomerNumber"]
        print "Warranties:"
        for warranty in info["Warranties"]["Warranty"]:
            print "\tStart Date: %s" % warranty["StartDate"]
            print "\tEnd Date: %s" % warranty["EndDate"]
            print "\tItem Number: %s" % warranty["ItemNumber"]
            print "\tEntitlement Type: %s" % warranty["EntitlementType"]
            print "\tService Provider: %s" % warranty["ServiceProvider"]
            print "\tService Level Code: %s" % warranty["ServiceLevelCode"]
            print "\tService Level Description: %s" % warranty["ServiceLevelDescription"]
            print

def convertdate(line):
    '''Based on RegEx match, convert date string to time object for future parsing'''
    if match('[\d]{1,2}/[\d]{1,2}/[\d]{4}',line): 
        return strptime(line,"%m/%d/%Y")
    elif match('[\d]{4}-[\d]{1,2}-[\d]{1,2}',line):
        return strptime(line,"%Y-%m-%d")
    elif match('[\d]{1,2} (Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec) [\d]{4}',line):
        return strptime(line,"%d %b %Y")
    else:
        return False #Not a Date

def main():
    config = ConfigParser.ConfigParser()
    config.readfp(open("config.ini"))

    warranty = Warranty(config)
    #warranty.gethostinfo()
    print warranty.getDellWarranty("node1162.broadinstitute.org", "BNC1DH1")
    warranty.db.finish()

# Standard boilerplate to call the main() function to begin the program.
if __name__ == "__main__":
    ret = main()

    exit(ret)
