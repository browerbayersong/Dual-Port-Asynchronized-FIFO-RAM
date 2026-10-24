// Replay only DUT input events exported by ModelSim. Check accepted transfers independently.
#include "Vnative_coverage_top.h"
#include "verilated.h"
#include "verilated_cov.h"
#include <array>
#include <cstdint>
#include <deque>
#include <fstream>
#include <iostream>
#include <sstream>
#include <stdexcept>
#include <string>
#include <unordered_map>

int main(int argc, char** argv) try {
    if(argc < 3) throw std::runtime_error("usage: replay input.vcd coverage.dat [--inject-check-fault]");
    const bool inject = argc > 3 && std::string(argv[3]) == "--inject-check-fault";
    VerilatedContext ctx; ctx.commandArgs(argc, argv);
    Vnative_coverage_top top{&ctx};
    std::ifstream input(argv[1]);
    if(!input) throw std::runtime_error("cannot open VCD");
    const std::array<std::string,15> names = {"rst_n","a_wr_clk","a_wr_en","a_wr_data",
        "a_rd_clk","a_rd_en","a_rd_ready","b_wr_clk","b_wr_en","b_wr_data",
        "b_rd_clk","b_rd_en","b_rd_ready","monitor_clk","snapshot_req"};
    std::unordered_map<std::string,std::pair<int,int>> symbols;
    std::array<bool,15> seen{};
    std::array<uint32_t,15> values{};
    std::array<std::deque<uint32_t>,2> queues;
    std::array<uint64_t,2> writes{}, reads{}, discarded{};
    uint64_t checks=0, timestamp=0, groups=0;
    bool fault_used=false;
    auto check = [&](bool ok, const char* message) {
        ++checks;
        if(!ok) throw std::runtime_error(std::string(message)+" at VCD time "+std::to_string(timestamp));
    };
    auto evaluate = [&](const std::array<uint32_t,15>& next) {
        // Values before the rising edge define acceptance, as in the SV scoreboard.
        const bool reset = next[0] == 0;
        std::array<bool,2> wr_edge = {!values[1]&&next[1],!values[7]&&next[7]};
        std::array<bool,2> rd_edge = {!values[4]&&next[4],!values[10]&&next[10]};
        std::array<bool,2> wr_ok = {bool(top.a_wr_rst_done&&!top.a_full&&next[2]),
                                  bool(top.b_wr_rst_done&&!top.b_full&&next[8])};
        std::array<bool,2> rd_ok = {bool(top.a_rd_rst_done&&!top.a_empty&&next[5]&&next[6]),
                                  bool(top.b_rd_rst_done&&!top.b_empty&&next[11]&&next[12])};
        std::array<bool,2> rd_done = {bool(top.a_rd_rst_done),bool(top.b_rd_rst_done)};
        std::array<uint32_t,2> held = {top.a_rd_data,top.b_rd_data}, expected{};
        if(reset) {
            for(int ch=0;ch<2;++ch){discarded[ch]+=queues[ch].size();queues[ch].clear();}
        } else {
            for(int ch=0;ch<2;++ch) {
                if(wr_edge[ch]&&wr_ok[ch]) {
                    queues[ch].push_back(next[ch==0?3:9]);++writes[ch];
                    check(queues[ch].size()<=256,"capacity");
                }
                if(rd_edge[ch]&&rd_ok[ch]) {
                    check(!queues[ch].empty(),"unexpected pop");
                    expected[ch]=queues[ch].front();queues[ch].pop_front();++reads[ch];
                    if(inject&&!fault_used){expected[ch]^=1;fault_used=true;}
                }
            }
        }
        top.rst_n=next[0];top.a_wr_clk=next[1];top.a_wr_en=next[2];top.a_wr_data=next[3];
        top.a_rd_clk=next[4];top.a_rd_en=next[5];top.a_rd_ready=next[6];
        top.b_wr_clk=next[7];top.b_wr_en=next[8];top.b_wr_data=next[9];
        top.b_rd_clk=next[10];top.b_rd_en=next[11];top.b_rd_ready=next[12];
        top.monitor_clk=next[13];top.snapshot_req=next[14];
        ctx.time(timestamp);top.eval();
        for(int ch=0;ch<2;++ch) if(!reset&&rd_edge[ch]&&rd_done[ch]) {
            const bool valid=ch==0?top.a_rd_data_valid:top.b_rd_data_valid;
            const uint32_t data=ch==0?top.a_rd_data:top.b_rd_data;
            check(valid==rd_ok[ch],"read valid");
            check(data==(rd_ok[ch]?expected[ch]:held[ch]),"read data / order / hold");
        }
        values=next;++groups;
    };
    std::string line;
    bool header=true, have_time=false;
    auto pending=values;
    while(std::getline(input,line)) {
        if(line.empty()) continue;
        if(header) {
            if(line.rfind("$var ",0)==0) {
                std::istringstream row(line);std::string tag,type,width,id,name;
                row>>tag>>type>>width>>id>>name;
                std::string range;row>>range;
                int bit=-1;
                if(width=="1"&&!range.empty()&&range[0]=='[')bit=std::stoi(range.substr(1));
                for(int i=0;i<15;++i) if(name==names[i]) {symbols[id]={i,bit};seen[i]=true;}
            }
            if(line.rfind("$enddefinitions",0)==0) {
                for(bool found:seen)check(found,"missing VCD input");header=false;
            }
            continue;
        }
        if(line[0]=='#') {
            if(have_time) evaluate(pending);
            timestamp=std::stoull(line.substr(1));have_time=true;pending=values;
        } else if(line[0]!='$') {
            std::string bits,id;
            if(line[0]=='b'||line[0]=='B') {std::istringstream row(line.substr(1));row>>bits>>id;}
            else {bits=line.substr(0,1);id=line.substr(1);}
            auto found=symbols.find(id);
            if(found!=symbols.end()) {
                bool unknown=bits.find_first_not_of("01")!=std::string::npos;
                check(!unknown||timestamp==0,"unknown input after time zero");
                auto [index,bit]=found->second;
                uint32_t value=unknown?0:static_cast<uint32_t>(std::stoull(bits,nullptr,2));
                if(bit<0)pending[index]=value;
                else pending[index]=(pending[index]&~(uint32_t(1)<<bit))|((value&1)<<bit);
            }
        }
    }
    if(have_time)evaluate(pending);
    for(int ch=0;ch<2;++ch) {
        check(queues[ch].empty(),"not fully drained");
        check(writes[ch]==reads[ch]+discarded[ch],"reset accounting");
        std::cout<<"CHANNEL "<<ch<<" writes="<<writes[ch]<<" reads="<<reads[ch]<<" reset_discarded="<<discarded[ch]<<"\n";
    }
    top.final();ctx.coveragep()->write(argv[2]);
    std::cout<<"RESULT: PASS native replay checks="<<checks<<" timestamp_groups="<<groups<<"\n";
    return 0;
} catch(const std::exception& e) {
    std::cerr<<"RESULT: FAIL "<<e.what()<<"\n";return 1;
}
