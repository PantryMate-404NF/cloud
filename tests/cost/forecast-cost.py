#!/usr/bin/env python3
import argparse
p=argparse.ArgumentParser(description='Flat monthly spend scenario, no growth assumption')
p.add_argument('--monthly-usd',type=float,required=True)
p.add_argument('--growth-monthly',type=float,default=0,help='e.g. 0.02 for 2% monthly growth')
a=p.parse_args()
for n in (3,6):
 vals=[a.monthly_usd*(1+a.growth_monthly)**i for i in range(n)]
 print(f'{n}-month cumulative: ${sum(vals):.2f}; month {n}: ${vals[-1]:.2f}')
print('Scenario estimate only, not an AWS billing forecast.')
