#!/usr/bin/env python3
import argparse,json
p=argparse.ArgumentParser(description='Scenario-based estimate; enter actual hourly rates')
p.add_argument('--config',required=True,help='JSON array: name,count,hours_per_month,hourly_usd')
a=p.parse_args()
rows=json.load(open(a.config))
total=0
for x in rows:
 cost=float(x['count'])*float(x['hours_per_month'])*float(x['hourly_usd'])
 total+=cost
 print(f"{x['name']}: ${cost:.2f}/month")
print(f"TOTAL estimated: ${total:.2f}/month (excludes unlisted services, tax and credits)")
