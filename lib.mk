
# Zabbix sql commandline wrapper
ifeq ($(ZABBIX_DB_TYPE),MYSQL)
 ZSQL = mysql '-u$(ZABBIX_DB_USER)' '-p$(ZABBIX_DB_PASSWORD)' '-h$(ZABBIX_DB_SERVER)' '-P$(ZABBIX_DB_PORT)' -A '-D$(ZABBIX_DB)'
 ZSQLC = mysql '-u$(ZABBIX_DB_USER)' '-p$(ZABBIX_DB_PASSWORD)' '-h$(ZABBIX_DB_SERVER)' '-P$(ZABBIX_DB_PORT)' -A '-D$(ZABBIX_DB)' -e
else
 ZSQL = PGPASSWORD='$(ZABBIX_DB_PASSWORD)' psql -U '$(ZABBIX_DB_USER)' -h '$(ZABBIX_DB_SERVER)' -p '$(ZABBIX_DB_PORT)' -d '$(ZABBIX_DB)'
 ZSQLC = PGPASSWORD='$(ZABBIX_DB_PASSWORD)' psql -U '$(ZABBIX_DB_USER)' -h '$(ZABBIX_DB_SERVER)' -p '$(ZABBIX_DB_PORT)' -d '$(ZABBIX_DB)' -c
endif

# Verbose
ifneq ($(V),)
 GH=./gethistory.php -e
 OCTAVE=octave
else
 GH=./gethistory.php
 OCTAVE=octave -q
endif

define analyze/octave
      $(OCTAVE) analyze.m $(1) $(2) $(TIME_PRECISION)
endef

define analyze/octave/graphs
      $(OCTAVE) graphs.m $(1) png
endef

ifeq ($(ZABBIX_HISTORY),backup)
 GH += -B
endif
ifeq ($(ZABBIX_HISTORY),sql)
 GH += -S
endif

#Output dir
ifeq ($(OUTDIR),)
O=out
else
O=$(OUTDIR)
endif

define testtool
	@if ! which $(1) >/dev/null; then echo $(2); exit 2; fi
endef

# Parameter: host start_date interval start_time
define analyze/host/interval
 get-$(1)-$(2)-$(3): $(O)/$(1)-$(2)-$(3).m
 analyze-$(1)-$(2)-$(3): $(O)/$(1)-$(2)-$(3).az
 graphs-$(1)-$(2)-$(3): $(O)/$(1)-$(2)-$(3).az
	@$(call analyze/octave/graphs,$(O)/$(1)-$(2)-$(3).az)
 $(1)-$(2)-$(3): $(O)/$(1)-$(2)-$(3).az
 $(O)/$(1)-$(2)-$(3).m:
	@echo Getting host $(1) from $(2), interval $(3)
 ifeq ($(V),)
	@$(GH) -f "$(4)" -T "$(3)" -i '$(PERSERVER)' -H '$(1)' >$(O)/$(1)-$(2)-$(3).m.tmp && mv $(O)/$(1)-$(2)-$(3).m.tmp $(O)/$(1)-$(2)-$(3).m;
 else
	$(GH) -f "$(4)" -T "$(3)" -i '$(PERSERVER)' -H '$(1)' >$(O)/$(1)-$(2)-$(3).m.tmp && mv $(O)/$(1)-$(2)-$(3).m.tmp $(O)/$(1)-$(2)-$(3).m;
 endif
 $(O)/$(1)-$(2)-$(3).az: $(O)/$(1)-$(2)-$(3).m
	@$(call analyze/octave,$(O)/$(1)-$(2)-$(3).m,$(O)/$(1)-$(2)-$(3).az.tmp) && mv $(O)/$(1)-$(2)-$(3).az.tmp $(O)/$(1)-$(2)-$(3).az;
endef

# Parameter: host
define analyze/host
get-$(1): $(foreach start_date,$(START_DATES),$(foreach interval,$(INTERVALS),get-$(1)-$(shell date -d "$(start_date)" +%Y_%m_%d_%H00)-$(interval)))
analyze-$(1): $(foreach start_date,$(START_DATES),$(foreach interval,$(INTERVALS),analyze-$(1)-$(shell date -d "$(start_date)" +%Y_%m_%d_%H00)-$(interval)))
graphs-$(1): $(foreach start_date,$(START_DATES),$(foreach interval,$(INTERVALS),graphs-$(1)-$(shell date -d "$(start_date)" +%Y_%m_%d_%H00)-$(interval)))
$(1): analyze-$(1)
$(foreach start_date,$(START_DATES),$(foreach interval,$(INTERVALS),$(eval $(call analyze/host/interval,$(1),$(shell date -d "$(start_date)" +%Y_%m_%d_%H00),$(interval),$(start_date)))))
clean-$(1):
	rm -rf $(O)/$(1)*
endef

ifneq ($(wildcard config.inc.php),)
 ifeq ($(HOSTS),)
  ifneq ($(HOSTGROUP),)
   HOSTS=$(shell ./gethostsingroup.php $(HOSTGROUP))
  endif
 endif
endif

START_DATES=$(TIME_START)
ifneq ($(TIME_TO),)
 ifneq ($(TIME_STEP),)
  START_DATES=$(shell ./dateintervals.php -F '$(TIME_START)' -T '$(TIME_TO)' -S '$(TIME_STEP)' -t '3600' -D '@U')
  START_DATES_NICE=$(shell ./dateintervals.php -F '$(TIME_START)' -T '$(TIME_TO)' -S '$(TIME_STEP)' -t '3600' -D 'Y_m_d_H_i')
 endif
endif
