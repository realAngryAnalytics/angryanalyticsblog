import csv
import re
import collections
import json

Token = collections.namedtuple('Token', ['typ', 'value', 'line', 'column'])

def tokenize(line):
    token_specification = [
        ('SPEED_IN_OUT',    r'(\d+(\.\d*)?/\d+(\.\d*)?\s{1}MPH)'),  # speed with multiple values (ex. 15/10 MPH)
        ('SPEED',           r'(\d+(\.\d*)?\s{1}MPH)'),  # speed with one value (ex. 10 MPH)
        ('LENGTH',          r'(\d+(\.\d*)?\s{1}Feet)'),  # length in feet (ex. 10 Feet)
        ('TEMP',            r'(\d+(\.\d*)?\s{1}[F])'),  # Temperature in Fahrenheit (ex. 83 F)
        ('DATETIME',        r'(\d+:(\d+(:\d)*)*)+\s+(\d+-\d+-\d+)'),  # Datetime value (ex. 00:00:00  12-12-2017)
        ('TIME',            r'(\d+:(\d+(:\d)*)*)+'),  # time value only (ex. 00:02   or   ex.  00:02:02)  
        ('ID_W_NBR',        r'(\d+(\.\d*)?\s([/\w]+\s?)+)'),  # ID that is prefixed by a number    
        ('NUMBER',  r'\d+(\.\d*)?'),  # Integer or decimal number    
        ('ID',      r'([/\w]+\s?)+'), # Identifiers
        ('ASSIGN',  r': '),           # Assignment operator
        ('NEWLINE', r'\n'),           # Line endings
        ('SKIP',    r'[ \t]+'),       # Skip over spaces and tabs
    ]
    tok_regex = '|'.join('(?P<%s>%s)' % pair for pair in token_specification)

    line_num = 1
    line_start = 0
    for match in re.finditer(tok_regex, line):
        kind = match.lastgroup
        value = match.group(kind)
        if kind == 'NEWLINE':
            line_start = match.end()
            line_num += 1
        elif kind == 'SKIP':
            pass
        else:
            column = match.start() - line_start
            token = Token(kind, value.strip(), line_num, column)
            yield token

lines = list(csv.reader(open('truck01.txt',mode='r'),delimiter='\t'))

counter = 0
ls = []
for l in lines:

    if len(l)==0 or counter == 0:
        counter += 1
        continue

    str = l[0]
    index = str.find(":")
    if(index == -1 and counter != 0):
        break

    print(str)
    for tok in tokenize(l[0]):
        print(tok)

    counter += 1
    
    #Below is where the header processing takes place
    dict = {}
    id = None
    assign_next_value = False
    for tok in tokenize(l[0]):
        print(tok)
        if tok.typ == "ASSIGN":
            assign_next_value = True
        elif assign_next_value:
            dict = {id:tok.value}
            print(dict)
            ls.append(dict)
            assign_next_value = False
            id = None
            dict = {}
        else:
            id = tok.value

jsondata = json.dumps(ls,indent=2,separators=(",",":"))
print(jsondata)