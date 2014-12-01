<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" xmlns:pekoe="http://www.gspring.com.au/pekoe" xmlns:school-booking="school-booking" xmlns:xs="http://www.w3.org/2001/XMLSchema" version="2.0">
    <xsl:include href="/db/pekoe-system/common.xsl"/>
    <xsl:function name="school-booking:address-on-one-line">
        <xsl:param name="path"/>
        <!--Has output xpath-->
        <xsl:value-of select="string-join($path/address/(line1, suburb, state, postcode),' ')"/>
    </xsl:function>
    <xsl:function name="school-booking:school-name">
        <xsl:param name="path"/>
        <!--Has output xpath-->
        <xsl:value-of select="$path/name"/>
    </xsl:function>
    <xsl:function name="school-booking:visit-date">
        <xsl:param name="path"/>
        <!--Has output xpath-->
        <xsl:value-of select="pekoe:aust-short-date($path/date)"/>
    </xsl:function>
    <xsl:function name="school-booking:total">
        <xsl:param name="path"/>
        <!--Has output xpath-->
        <xsl:value-of select="pekoe:currency(number($path/attendance/actual) * number($root/school-booking/student-fee))"/>
    </xsl:function>
    <xsl:function name="school-booking:currency">
        <xsl:param name="path"/>
        <xsl:value-of select="concat('$',string($path))"/>
    </xsl:function>
    <xsl:function name="school-booking:booked">
        <xsl:param name="path"/>
        <xsl:value-of select="$path/booked"/>
    </xsl:function>
</xsl:stylesheet>