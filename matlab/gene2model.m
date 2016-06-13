%AUTHOR: MOHAMMAD MAHDI GHASSEMI
%EMAIL: ghassemi@mit.edu

function [fun_out, b_i] =gene2model(x, genes)
%genes is a column of 0s and 1s that say if the feature is on or off.
%Define THE OVERALL STRUCTURE OF THE "GENOME"
%model = @(b,x) b(1) + b(2)*x(:,1).^(b(3)) + ...
%                      b(4)*x(:,2).^(b(5)) + ...
%                      b(6)*x(:,3).^(b(7)) + ...
%                      b(8)*x(:,4).^(b(9)) + ...
%                      b(10)*x(:,5).^(b(11)) + ...
%                      b(12)*x(:,6).^(b(13)) + ...
%                      b(14)*x(:,7).^(b(15)) + ...
%                      b(16)*x(:,8).^(b(17)) + ...
%                      b(18)*x(:,9).^(b(19));
                 
num_betas = 2*size(x,2) + 1;
%Generate a genome
%genes = randi(2,num_betas,1)-1;
model_params = find(genes);

x_i = 1;
b_i = 2;
out = [];
for(i = 2:2:2*size(x,2))   
    if( i == 2)
       out = [out,'b(1) + '];
    end
    
    %% IF i is on
    if(sum(i == model_params) & sum(i+1 == model_params))
    out = [out,['b(' num2str(b_i) ')*x(:,' num2str(x_i) ').^(b(' num2str(b_i+1) ')) + ']];
    b_i = b_i + 2; 
    %If it's even - mutiplicative
    elseif(sum( i == model_params)) 
    out = [out,['b(' num2str(b_i) ')*x(:,' num2str(x_i) ') + ']];
    b_i = b_i + 1;
    %If it's odd - exponential
    elseif(sum(i+1 == model_params))
    out = [out,['x(:,' num2str(x_i) ').^(b(' num2str(b_i) ')) + ']];
    b_i = b_i + 1;    
    end
    x_i = x_i + 1;
end
out = out(1:end-2); 
b_i = b_i - 1;

eval(['fun_out = @(b,x)' out ';'])

end