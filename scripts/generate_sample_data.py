"""StressLens POC: sample data + reference calculation (expected results for QA).

Run from the repo root:  python scripts/generate_sample_data.py
Writes:
  data/landing/2026-06-30/  raw source files, with the 12 seeded defects
  data/fixes/2026-06-30/    corrected / supplementary records that resolve them
  data/expected/            QA oracle: 120 loan-scenario results + portfolio summary
All data is synthetic. Formulas follow PRD section 9 (POC simplifications).
"""
import csv, os, json

ASOF = "2026-06-30"
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "data", "landing", ASOF)
FIX = os.path.join(ROOT, "data", "fixes", ASOF)
EXP = os.path.join(ROOT, "data", "expected")
for d in (OUT, FIX, EXP):
    os.makedirs(d, exist_ok=True)

# ---------------- customers (source as received) ----------------
customers = [
 # id, name, naics, state, rating, since
 ("C0001","Blue Ridge Logistics Inc","484121","VA",4,"2012-04-02"),
 ("C0002","Canyon Foods Distribution LLC","424410","AZ",5,"2015-09-14"),
 ("C0003","Harborview Office Partners LP","531120","MA",4,"2016-01-20"),
 ("C0004","Prairie Ag Equipment Co","423820","KS",6,"2011-06-30"),
 ("C0005","Summit Medical Devices Inc","339112","MN",3,"2018-03-05"),
 ("C0006","Riverbend Apartments LLC","531110","TX",4,"2017-07-11"),
 ("C0007","Lakeside Precision Tooling LLC","332710","OH",5,"2014-03-01"),
 ("C0008","Golden Gate Retail Center LP","531120","CA",6,"2013-10-22"),
 ("C0009","Keystone Building Supply Inc","444110","PA",5,"2019-02-18"),
 ("C0010","Metro Industrial Park LLC","531130","IL",3,"2016-08-09"),
 ("C0011","Coastal Seafood Processors Inc","311710","ME",7,"2010-05-17"),
 ("C0012","Pinecrest Senior Living LLC","531110","NC",5,"2020-01-06"),
 ("C0013","Ironclad Security Services Inc","561612","GA",4,"2018-11-13"),
 ("C0014","Northstar Software Solutions Inc",None,"WA",3,"2021-04-26"),
 ("C0015","Desert Sun Hospitality Group LLC","721110","NV",7,"2015-12-01"),
 ("C0016","Great Lakes Plastics Corp","326199","MI",6,"2012-09-24"),
 ("C0017","Midtown Office Tower LLC","531120","NY",5,"2014-06-16"),
 ("C0018","Sunbelt Distribution Center LP","531130","FL",4,"2019-05-07"),
 ("C0019","Heritage Furniture Makers Inc","337122","NC",None,"2011-02-14"),
 ("C0020","Bayou Energy Services LLC","213112","LA",8,"2013-08-19"),
 ("C0021","Oakwood Garden Apartments LP","531110","GA",4,"2018-10-03"),
 ("C0022","Frontier Trucking Co","484121","NE",6,"2017-03-27"),
 ("C0023","Crescent Plaza Shopping Center LLC","531120","LA",7,"2012-12-10"),
 ("C0024","Evergreen Pharma Packaging Inc","325412","NJ",3,"2020-07-15"),
 ("C0025","Silverline Auto Parts Inc","441310","TN",5,"2016-05-23"),
]
# supplementary customer (resolves orphan FK C0026)
customer_fix = [("C0026","Redwood Craft Brewing Co","312120","OR",6,"2022-02-01")]

# ---------------- loans (source as received) ----------------
# id, cust, src_prod, orig, mat, commit, rate, rate_type, hvcre
loans = [
 ("LN1001","C0001","CIT","2021-03-15","2028-03-15",6000000,0.06850,"FLOAT","N"),
 ("LN1002","C0001","CIR","2023-01-10","2027-01-10",4000000,0.07400,"FLOAT","N"),
 ("LN1003","C0002","CIR","2022-06-01","2027-06-01",5000000,0.07600,"FLOAT","N"),
 ("LN1004","C0003","CRO","2019-09-30","2029-09-30",18000000,0.05250,"FIXED","N"),
 ("LN1005","C0004","CIT","2020-11-20","2027-11-20",3500000,0.07100,"FIXED","N"),
 ("LN1006","C0005","CIR","2024-02-12","2029-02-12",7500000,0.06900,"FLOAT","N"),
 ("LN1007","C0006","CRM","2018-05-01","2028-05-01",22000000,0.04750,"FIXED","N"),
 ("LN1008","C0007","CIR","2021-08-18","2026-12-18",3000000,0.07750,"FLOAT","N"),
 ("LN1009","C0008","CRR","2017-04-11","2027-04-11",15000000,0.05600,"FIXED","N"),
 ("LN1010","C0009","CIR","2022-10-05","2027-10-05",4000000,0.07500,"FLOAT","N"),
 ("LN1011","C0010","CRI","2020-02-28","2030-02-28",20000000,0.05100,"FIXED","N"),
 ("LN1012","C0007","CIT","2022-05-16","2029-05-16",8000000,0.07250,"FLOAT","N"),
 ("LN1013","C0011","CIT","2019-07-22","2026-07-22",2500000,0.08100,"FIXED","N"),
 ("LN1014","C0012","CRM","2021-12-15","2031-12-15",16000000,0.05400,"FIXED","N"),
 ("LN1015","C0013","CIR","2023-04-03","2028-04-03",3000000,0.07300,"FLOAT","N"),
 ("LN1016","C0014","CIT","2024-06-28","2029-06-28",9000000,0.06650,"FLOAT","N"),
 ("LN1017","C0015","CRR","2016-03-18","2026-09-18",12000000,0.06100,"FIXED","N"),
 ("LN1018","C0016","CIT","2020-09-09","2027-09-09",5500000,None,"FIXED","N"),
 ("LN1019","C0017","CRO","2018-11-01","2028-11-01",30000000,0.04900,"FIXED","N"),
 ("LN1020","C0018","CRI","2021-06-14","2031-06-14",14000000,0.05300,"FIXED","N"),
 ("LN1021","C0019","CIT","2019-01-25","2027-01-25",4500000,0.07000,"FIXED","N"),
 ("LN1022","C0020","CIR","2022-03-30","2027-03-30",6000000,0.08500,"FLOAT","N"),
 ("LN1023","C0017","CRO","2025-01-15","2028-01-15",10000000,0.07900,"FLOAT","Y"),
 ("LN1024","C0021","CRM","2019-08-20","2029-08-20",12500000,0.04600,"FIXED","N"),
 ("LN1025","C0022","CIT","2021-10-12","2028-10-12",5000000,0.07150,"FIXED","N"),
 ("LN1026","C0023","CRR","2015-07-07","2027-07-07",9500000,0.05900,"FIXED","N"),
 ("LN1027","C0024","CIR","2023-09-19","2028-09-19",6500000,0.06800,"FLOAT","N"),
 ("LN1028","C0025","CIT","2020-04-01","2027-04-01",3800000,0.07050,"FIXED","N"),
 ("LN1029","C0002","CIT","2021-12-01","2028-12-01",4200000,0.07200,"FIXED","N"),
 ("LN1030","C0011","CIR","2022-07-15","2027-07-15",2000000,0.08300,"FLOAT","N"),
 ("LN1031","C0003","CRO","2022-11-30","2032-11-30",11000000,0.05800,"FIXED","N"),
 ("LN1032","C0005","CIT","2023-05-22","2030-05-22",7000000,0.06700,"FLOAT","N"),
 ("LN1033","C0010","CRI","2024-08-08","2034-08-08",9000000,0.06200,"FIXED","N"),
 ("LN1034","C0013","CIT","2022-01-18","2027-01-18",2800000,0.07350,"FIXED","N"),
 ("LN1035","C0015","CIR","2023-02-27","2027-02-27",3500000,0.08200,"FLOAT","N"),
 ("LN1036","C0012","CRM","2024-10-01","2034-10-01",13000000,0.06000,"FIXED","N"),
 ("LN1037","C0022","CIR","2024-03-11","2028-03-11",2500000,0.07600,"FLOAT","N"),
 ("LN1038","C0026","CIT","2025-02-03","2030-02-03",3200000,0.07450,"FLOAT","N"),
 ("LN1039","C0024","CIT","2021-06-25","2028-06-25",5200000,0.06550,"FIXED","N"),
 ("LN1040","C0021","CRM","2025-04-30","2035-04-30",8500000,0.06300,"FIXED","N"),
]

# ---------------- balances (source as received) ----------------
bal = {
 "LN1001":4200000,"LN1002":2600000,"LN1003":3100000,"LN1004":16200000,"LN1005":2150000,
 "LN1006":3900000,"LN1007":19800000,"LN1008":2750000,"LN1009":13100000,"LN1010":4350000,
 "LN1011":18300000,"LN1012":6250000,"LN1013":650000,"LN1014":15400000,"LN1015":1800000,
 "LN1016":8600000,"LN1017":11200000,"LN1018":3300000,"LN1019":27500000,"LN1020":13300000,
 "LN1021":-2250000,"LN1022":5400000,"LN1023":7800000,"LN1024":11100000,"LN1025":3900000,
 "LN1026":8800000,"LN1027":2200000,"LN1028":1900000,"LN1029":3600000,"LN1030":1950000,
 "LN1031":10600000,"LN1032":6400000,"LN1034":1500000,"LN1035":3100000,
 "LN1036":12800000,"LN1037":900000,"LN1038":3000000,"LN1039":3800000,"LN1040":8450000,
 "LN1041":2400000,   # orphan: not in loan master
}
dpd = {"LN1013":35,"LN1015":0,"LN1022":62,"LN1029":64,"LN1030":95,"LN1035":31,"LN1017":0}
bal_fix = {"LN1033":8700000, "LN1021":2250000}           # supplementary / corrected values
commit_fix = {"LN1010":4500000}                          # amendment not reflected in master
rate_fix = {"LN1018":0.06950}
rating_fix = {"C0019":7}                                 # conservative default, documented override

balance_rows = []
for lid, b in bal.items():
    balance_rows.append((lid, ASOF, b, dpd.get(lid, 0), "141000" if lid in {l[0] for l in loans if l[2].startswith("CI")} or lid=="LN1041" else "142000"))
    if lid == "LN1025":
        balance_rows.append((lid, ASOF, b, 0, "141000"))  # exact duplicate

# ---------------- status history (source as received) ----------------
status = []
sid = 50001
def st(lid, code, eff, ts):
    global sid
    status.append((sid, lid, code, eff, ts)); sid += 1
for l in loans:
    st(l[0], "C", l[3], l[3] + " 06:00:00")
st("LN1013","30","2026-06-05","2026-06-06 06:00:00")
st("LN1022","30","2026-05-01","2026-05-02 06:00:00")
st("LN1022","60","2026-05-31","2026-06-01 06:00:00")
st("LN1029","XX","2026-05-28","2026-05-29 06:00:00")          # invalid code
st("LN1030","30","2026-04-20","2026-04-21 06:00:00")
st("LN1030","60","2026-05-20","2026-05-21 06:00:00")
st("LN1030","90","2026-06-19","2026-06-20 06:00:00")
st("LN1035","30","2026-05-30","2026-05-31 06:00:00")
st("LN1015","30","2026-06-15","2026-06-16 06:00:00")          # tie on effective date...
st("LN1015","C","2026-06-15","2026-06-16 14:30:00")           # ...later load wins: cured
st("LN1017","NA","2026-03-31","2026-04-01 06:00:00")          # nonaccrual CRE retail
status_fix = {"LN1029":"60"}

# ---------------- collateral (source as received) ----------------
coll = [
 # id, loan, src_type, value, valuation_date
 ("CL2001","LN1001","EQP",3000000,"2025-09-30"),
 ("CL2002","LN1003","ARI",2500000,"2026-03-31"),
 ("CL2003","LN1004","OFF",25000000,"2025-06-15"),
 ("CL2004","LN1005","EQP",1800000,"2025-12-31"),
 ("CL2005","LN1007","MFR",33000000,"2025-10-01"),
 ("CL2006","LN1009","RTL",19000000,"2023-02-10"),   # stale (>24 months)
 ("CL2007","LN1011","IND",30500000,"2025-08-20"),
 ("CL2008","LN1014","MFR",22000000,"2025-12-05"),
 ("CL2009","LN1017","RTL",12500000,"2026-01-15"),
 ("CL2010","LN1019","OFF",36000000,"2025-11-20"),
 ("CL2011","LN1020","IND",21000000,"2026-02-28"),
 ("CL2012","LN1022","EQP",3500000,"2025-07-31"),
 ("CL2013","LN1023","OFF",11500000,"2025-01-05"),
 ("CL2014","LN1024","MFR",17500000,"2025-09-09"),
 ("CL2015","LN1025","EQP",2800000,"2025-11-30"),
 ("CL2016","LN1026","RTL",11000000,"2025-05-19"),
 ("CL2017","LN1028","EQP",1200000,"2026-01-31"),
 ("CL2018","LN1030","ARI",1000000,"2026-03-31"),
 ("CL2019","LN1031","OFF",16000000,"2024-11-30"),
 ("CL2020","LN1033","IND",13500000,"2024-07-25"),
 ("CL2021","LN1036","MFR",18500000,"2024-09-15"),
 ("CL2022","LN1040","MFR",12000000,"2025-04-10"),
 ("CL2023","LN1037","ARI",1500000,"2026-03-31"),
 ("CL2024","LN1011","IND",2000000,"2025-08-20"),    # second item on same loan
]

code_map_asis = {  # (code_type, src) -> target ; CRM deliberately wrong
 ("PRODUCT","CIT"):"CI_TERM",("PRODUCT","CIR"):"CI_REVOLVER",("PRODUCT","CRO"):"CRE_OFFICE",
 ("PRODUCT","CRM"):"CI_TERM",("PRODUCT","CRR"):"CRE_RETAIL",("PRODUCT","CRI"):"CRE_INDUSTRIAL",
 ("STATUS","C"):"CURRENT",("STATUS","30"):"DPD30",("STATUS","60"):"DPD60",("STATUS","90"):"DPD90",
 ("STATUS","NA"):"NONACCRUAL",("STATUS","PO"):"PAIDOFF",
 ("COLLATERAL","OFF"):"CRE_OFFICE",("COLLATERAL","MFR"):"CRE_MF",("COLLATERAL","RTL"):"CRE_RETAIL",
 ("COLLATERAL","IND"):"CRE_IND",("COLLATERAL","EQP"):"EQUIPMENT",("COLLATERAL","ARI"):"AR_INV",
}
code_map = dict(code_map_asis); code_map[("PRODUCT","CRM")] = "CRE_MULTIFAMILY"

# ---------------- write source CSVs ----------------
def w(name, header, rows, folder=OUT):
    with open(os.path.join(folder, name), "w", newline="") as f:
        cw = csv.writer(f); cw.writerow(header)
        for r in rows: cw.writerow(["" if v is None else v for v in r])
w("loansys_customer.csv",["customer_id","customer_name","naics_code","state_code","obligor_rating","customer_since"],customers)
w("loansys_loan.csv",["loan_id","customer_id","product_code","orig_date","maturity_date","commitment_amt","interest_rate","rate_type","hvcre_flag"],loans)
w("loansys_balance.csv",["loan_id","as_of_date","outstanding_bal","days_past_due","gl_account"],balance_rows)
w("loansys_status.csv",["status_hist_id","loan_id","status_code","effective_date","load_ts"],status)
w("collsys_collateral.csv",["collateral_id","loan_id","collateral_type","collateral_value","valuation_date"],coll)
w("ref_code_map.csv",["code_type","source_code","target_code"],[(k[0],k[1],v) for k,v in code_map_asis.items()])

# ---------------- GL control total (booked truth) ----------------
true_bal = {k:v for k,v in bal.items()}; true_bal.update(bal_fix)
gl = {"141000":0,"142000":0}
for r in loans:
    gl["141000" if r[2].startswith("CI") else "142000"] += true_bal[r[0]]
gl["141000"] += true_bal["LN1041"]
w("gl_control.csv",["gl_account","as_of_date","gl_balance"],[(k,ASOF,v) for k,v in gl.items()])

# ---------------- fixes that resolve the seeded defects (PRD section 7.1) ----------------
w("fix_customer_supplementary.csv",["customer_id","customer_name","naics_code","state_code","obligor_rating","customer_since"],customer_fix,FIX)
w("fix_rating_override.csv",["customer_id","field","new_value","reason"],
  [(k,"obligor_rating",v,"Conservative default pending credit review") for k,v in rating_fix.items()],FIX)
w("fix_loan_corrections.csv",["loan_id","field","new_value","reason"],
  [(k,"interest_rate",v,"Corrected by LOANSYS") for k,v in rate_fix.items()] +
  [(k,"commitment_amt",v,"Amendment not loaded to master") for k,v in commit_fix.items()],FIX)
w("fix_balance_supplementary.csv",["loan_id","as_of_date","outstanding_bal","days_past_due","gl_account","reason"],
  [("LN1033",ASOF,bal_fix["LN1033"],0,"142000","Missing from extract"),
   ("LN1021",ASOF,bal_fix["LN1021"],0,"141000","Sign error corrected")],FIX)
w("fix_status_corrections.csv",["loan_id","status_code","effective_date","reason"],
  [(k,v,"2026-05-28","Source confirmed 60 days past due") for k,v in status_fix.items()],FIX)
w("fix_code_map.csv",["code_type","source_code","target_code","reason"],
  [("PRODUCT","CRM","CRE_MULTIFAMILY","Was mapped to CI_TERM in error")],FIX)

# ---------------- recon stats (as received) ----------------
src_rows = len(balance_rows); src_sum = sum(r[2] for r in balance_rows)
stats = {"src_balance_rows":src_rows,"src_balance_sum":src_sum,"gl":gl,"gl_total":sum(gl.values())}

# ---------------- reference calculation on resolved data ----------------
BASE_PD = {1:.0005,2:.001,3:.003,4:.008,5:.02,6:.04,7:.08,8:.15,9:.30,10:1.0}
CCF=0.5; FLOOR=0.10; UNSEC=0.45; RCOST=0.10; HORIZON=2.25; TAX=0.21
SCEN = {
 "BASE":dict(pd_ci=1.0,pd_cre=1.0,cre=0.0,hc=0.0,ppnr=1.00),
 "MOD": dict(pd_ci=1.8,pd_cre=2.0,cre=-0.20,hc=0.15,ppnr=0.85),
 "SEV": dict(pd_ci=3.0,pd_cre=3.5,cre=-0.40,hc=0.30,ppnr=0.60),
}
cust = {c[0]:list(c) for c in customers+customer_fix}
for k,v in rating_fix.items(): cust[k][4]=v
L = {}
for r in loans:
    r=list(r); lid=r[0]
    if lid in commit_fix: r[5]=commit_fix[lid]
    if lid in rate_fix: r[6]=rate_fix[lid]
    L[lid]=r
# latest status (effective_date desc, load_ts desc)
latest={}
for s in status:
    k=(s[3],s[4])
    if s[1] not in latest or k>latest[s[1]][0]: latest[s[1]]=(k,s[2])
stat={lid:code_map[("STATUS",status_fix.get(lid,v[1]))] for lid,v in latest.items()}
cl={}
for c in coll: cl.setdefault(c[1],[]).append((code_map[("COLLATERAL",c[2])],c[3]))

rows=[]
for lid,r in L.items():
    prod=code_map[("PRODUCT",r[2])]; port="CRE" if prod.startswith("CRE") else "CI"
    ob=true_bal[lid]; und=max(0,r[5]-ob); ead=ob+CCF*und
    rating=cust[r[1]][4]; st_=stat[lid]
    bpd=BASE_PD[rating]
    if st_ in ("DPD90","NONACCRUAL"): bpd=1.0
    elif st_ in ("DPD30","DPD60"): bpd=max(bpd,0.15)
    rw=1.5 if (r[8]=="Y" or st_ in ("DPD90","NONACCRUAL")) else 1.0
    for sc,p in SCEN.items():
        m=p["pd_cre"] if port=="CRE" else p["pd_ci"]
        spd=1.0 if bpd==1.0 else min(1.0,bpd*m)
        cpd=1.0 if spd==1.0 else min(1.0,spd*HORIZON)
        items=cl.get(lid,[])
        if items:
            sv=sum(v*(1+p["cre"]) if t.startswith("CRE") else v*(1-p["hc"]) for t,v in items)
            rec=sv*(1-RCOST)
            lgd=min(UNSEC,max(FLOOR,1-rec/ead))
        else: lgd=UNSEC
        loss=round(cpd*lgd*ead,2)
        rows.append(dict(loan_id=lid,portfolio=port,product=prod,rating=rating,status=st_,scenario=sc,
            outstanding=ob,undrawn=und,ead=ead,base_pd=bpd,stressed_pd=round(spd,6),cum_pd=round(cpd,6),
            lgd=round(lgd,6),loss=loss,rw=rw,rwa=ead*rw,rate=r[6]))
with open(os.path.join(EXP,"expected_calc_result.csv"),"w",newline="") as f:
    cw=csv.DictWriter(f,fieldnames=list(rows[0].keys())); cw.writeheader(); cw.writerows(rows)

# aggregates
agg={}
for sc in SCEN:
    rs=[x for x in rows if x["scenario"]==sc]
    agg[sc]={"loss":round(sum(x["loss"] for x in rs),2),
             "loss_ci":round(sum(x["loss"] for x in rs if x["portfolio"]=="CI"),2),
             "loss_cre":round(sum(x["loss"] for x in rs if x["portfolio"]=="CRE"),2),
             "ead":sum(x["ead"] for x in rs),"rwa":sum(x["rwa"] for x in rs)}
base_rows=[x for x in rows if x["scenario"]=="BASE"]
tot_out=sum(x["outstanding"] for x in base_rows)
int_inc_q=sum(x["outstanding"]*x["rate"] for x in base_rows)/4
FUND=0.030
nii_q=int_inc_q - tot_out*FUND/4
NONII_Q=1200000; NONIE_Q=1900000
ppnr_q=nii_q+NONII_Q-NONIE_Q
OTHER_RWA=180_000_000
loan_rwa=agg["BASE"]["rwa"]; rwa0=loan_rwa+OTHER_RWA
CET1_0=round(0.12*rwa0,-5)   # 12.0% start, rounded
DIV_Q=500000
cap={}
for sc,p in SCEN.items():
    ppnr9=ppnr_q*9*p["ppnr"]; loss=agg[sc]["loss"]
    pti=ppnr9-loss; ni=pti*(1-TAX); div=DIV_Q*9
    cet1=CET1_0+ni-div
    cap[sc]=dict(ppnr_9q=round(ppnr9),loss=round(loss),pretax=round(pti),net_income=round(ni),
                 dividends=div,cet1_end=round(cet1),ratio_end=round(cet1/rwa0*100,2))
out=dict(stats=stats,agg=agg,tot_out=tot_out,int_inc_q=round(int_inc_q),nii_q=round(nii_q),ppnr_q=round(ppnr_q),
         loan_rwa=loan_rwa,rwa0=rwa0,cet1_0=CET1_0,ratio0=round(CET1_0/rwa0*100,2),cap=cap)
with open(os.path.join(EXP,"expected_portfolio_summary.json"),"w") as f:
    json.dump(out,f,indent=1)
print(json.dumps(out,indent=1))
