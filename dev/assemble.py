# Joins dev/src (page.html + style.css + js/*.js in file-name order) into the one game file.
# The pieces are cut from one file along its section headers, so joining them in order gives that file back exactly.
import os,glob
def assemble(src_dir):
    rd=lambda p:open(p,encoding='utf-8').read()
    page=rd(f'{src_dir}/page.html')
    css=rd(f'{src_dir}/style.css').rstrip('\n')
    js=''.join(rd(p) for p in sorted(glob.glob(f'{src_dir}/js/*.js'))).rstrip('\n')
    assert page.count('/*@@STYLE@@*/')==1 and page.count('/*@@SCRIPT@@*/')==1
    return page.replace('/*@@STYLE@@*/',css).replace('/*@@SCRIPT@@*/',js)
if __name__=='__main__':
    import sys;d=os.path.dirname(os.path.abspath(__file__))
    out=assemble(f'{d}/src')
    if len(sys.argv)>1:open(sys.argv[1],'w',encoding='utf-8').write(out)
    else:sys.stdout.write(out)
